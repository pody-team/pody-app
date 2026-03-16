package httpserver

import (
	"log/slog"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"

	"github.com/promex04/pody/server/api-gateway/internal/config"
)

func newServiceProxy(route config.ServiceRoute, logger *slog.Logger) (http.Handler, error) {
	target, err := url.Parse(route.TargetURL)
	if err != nil {
		return nil, err
	}

	basePrefix := strings.TrimSuffix(route.Prefix, "/")
	targetQuery := target.RawQuery

	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			originalHost := req.Host
			originalPath := req.URL.Path
			trimmedPath := strings.TrimPrefix(originalPath, basePrefix)
			if trimmedPath == "" {
				trimmedPath = "/"
			}
			if !strings.HasPrefix(trimmedPath, "/") {
				trimmedPath = "/" + trimmedPath
			}

			req.URL.Scheme = target.Scheme
			req.URL.Host = target.Host
			req.URL.Path = joinPaths(target.Path, trimmedPath)
			req.URL.RawPath = req.URL.EscapedPath()
			req.Host = target.Host

			switch {
			case targetQuery == "":
			case req.URL.RawQuery == "":
				req.URL.RawQuery = targetQuery
			default:
				req.URL.RawQuery = targetQuery + "&" + req.URL.RawQuery
			}

			req.Header.Set("X-Forwarded-Host", originalHost)
			req.Header.Set("X-Forwarded-Prefix", route.Prefix)
			req.Header.Set("X-Forwarded-Proto", forwardedProto(req))

			if requestID := requestIDFromContext(req.Context()); requestID != "" {
				req.Header.Set("X-Request-ID", requestID)
			}
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			logger.Error("proxy request failed",
				"request_id", requestIDFromContext(r.Context()),
				"service", route.Name,
				"target", route.TargetURL,
				"error", err,
			)
			writeJSON(w, http.StatusBadGateway, map[string]string{
				"error":   "upstream service unavailable",
				"service": route.Name,
			})
		},
	}

	return proxy, nil
}

func joinPaths(basePath, requestPath string) string {
	switch {
	case basePath == "" || basePath == "/":
		return requestPath
	case requestPath == "" || requestPath == "/":
		return strings.TrimRight(basePath, "/")
	default:
		return strings.TrimRight(basePath, "/") + "/" + strings.TrimLeft(requestPath, "/")
	}
}

func forwardedProto(req *http.Request) string {
	if req.TLS != nil {
		return "https"
	}

	if forwarded := strings.TrimSpace(req.Header.Get("X-Forwarded-Proto")); forwarded != "" {
		return forwarded
	}

	return "http"
}
