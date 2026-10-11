// Request abuse blocker: scanner/secret probes and attack headers.
// (No user-agent blocking here: short links must stay followable by any client.)
//
// Mount FIRST, before any other middleware or route, so abusive requests are
// dropped cheaply and never reach a handler. Path probes get a bare 404;
// everything else a bare 403.
//
//   app.use(require('./security'));

// Paths that must stay reachable for health checks and crawler discovery.
const SAFE_PATHS = new Set(["/", "/health", "/robots.txt", "/sitemap.xml", "/favicon.ico"]);

// Scanner/secret probes by path. Unmistakable names only.
const PROBE_PATH = new RegExp(
  [
    "\\.env\\b",
    "/\\.(git|aws|ssh|svn|hg)(/|$)",
    "/wp-(admin|content|includes|login|json|cron)\\b",
    "/xmlrpc\\.php",
    "\\.(php|sql|pem|p12|pfx|bak|swp)$",
    "id_rsa(\\.|$)",
    "/\\.(htaccess|htpasswd|DS_Store|npmrc)$",
    "/(phpmyadmin|pma|adminer)(/|\\.|$)",
    "/(cgi-bin|actuator|vendor/phpunit)(/|$)",
    "/web\\.config$",
  ].join("|"),
  "i",
);

// Probes carried in the raw (still URL-encoded) query string, e.g.
// /_image?href=/../../../.env or ?apis=../../../../.env
const PROBE_QUERY = new RegExp(
  [
    // a param value ending in a dotfile secret
    "(\\.|%2e)(env(\\.[\\w.-]+)?|git(/|\\\\|%2f|%5c)(config|HEAD)|htpasswd|htaccess|npmrc|DS_Store|aws(/|\\\\|%2f|%5c)credentials|ssh(/|\\\\|%2f|%5c)[\\w.-]+)(&|%00|$)",
    // a param value ending in a well-known config/secret file
    "(web\\.config|wp-config\\.php|appsettings(\\.\\w+)?\\.json|etc(/|\\\\|%2f|%5c)(passwd|shadow)|win\\.ini|boot\\.ini|id_rsa|id_ed25519)(&|%00|$)",
    // path traversal anywhere in the query
    "(\\.|%2e)(\\.|%2e)(/|\\\\|%2f|%5c)",
  ].join("|"),
  "i",
);

// Headers no legitimate client sends to these services.
// x-middleware-subrequest: Next.js middleware auth bypass (CVE-2025-29927);
// the rest are Next.js internals used for cache poisoning; proxy: httpoxy.
const FORBIDDEN_HEADERS = ["x-middleware-subrequest", "x-now-route-matches", "x-invoke-path", "x-invoke-status", "proxy"];
const RANGE_OVERFLOW = /18446744073709551615/; // HTTP.sys MS15-034
const SHELLSHOCK = /\(\s*\)\s*\{/;
const LOG4SHELL = /\$\{.*(jndi|lower:|upper:|env:|sys:|::-)/i;
const UA_PAYLOAD = /<\?php|<script|base64_decode|eval\(|union\s+select|\/etc\/passwd/i;
const XFF_PAYLOAD = /[<>'();]/;

// Returns why a request should be dropped, or null to let it through.
// `path` is the URL pathname, `query` the raw query string (no leading "?"),
// `header` reads one request header by lower-case name.
const checkRequest = (
  path,
  query,
  header,
) => {
  if (!SAFE_PATHS.has(path) && PROBE_PATH.test(path)) return "path";
  const ua = header("user-agent");
  if (query && PROBE_QUERY.test(query)) return "query";
  if (FORBIDDEN_HEADERS.some((name) => header(name) !== "")) return "header";
  const referer = header("referer");
  const xff = header("x-forwarded-for");
  if (RANGE_OVERFLOW.test(header("range"))) return "header";
  if (SHELLSHOCK.test(ua) || SHELLSHOCK.test(referer) || SHELLSHOCK.test(header("cookie"))) return "header";
  if (LOG4SHELL.test(ua) || LOG4SHELL.test(referer) || LOG4SHELL.test(xff) || LOG4SHELL.test(header("x-api-version"))) return "header";
  if (UA_PAYLOAD.test(ua) || XFF_PAYLOAD.test(xff)) return "header";
  return null;
};

const blockAbuse = (req, res, next) => {
  const [path, query = ""] = String(req.originalUrl || req.url || "").split("?");
  const reason = checkRequest(path, query, (name) => String(req.headers[name] || ""));
  if (!reason) return next();
  res.status(reason === "path" ? 404 : 403).end();
};

module.exports = blockAbuse;
module.exports.checkRequest = checkRequest;
