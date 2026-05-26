package httpserver

import (
	_ "embed"
	"fmt"
	"net/http"
)

// openAPISpec nhúng trực tiếp file tài liệu openapi.yaml vào trong binary thực thi (sử dụng go:embed).
//go:embed docs/openapi.yaml
var openAPISpec []byte

// handleOpenAPI trả về nội dung của file cấu hình đặc tả OpenAPI spec dưới dạng application/yaml.
func (s *Server) handleOpenAPI(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/yaml")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(openAPISpec)
}

// handleSwaggerUI trả về mã nguồn HTML hiển thị giao diện tương tác Swagger UI cho các API.
func (s *Server) handleSwaggerUI(w http.ResponseWriter, r *http.Request) {
	specURL := "/api/v1/public/identity/openapi.yaml"
	html := fmt.Sprintf(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Pody Identity API Docs</title>
    <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
  </head>
  <body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
    <script>
      window.ui = SwaggerUIBundle({
        url: %q,
        dom_id: '#swagger-ui'
      });
    </script>
  </body>
</html>`, specURL)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(html))
}

