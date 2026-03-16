package config

import (
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"
)

type ServiceRoute struct {
	Name      string `json:"name"`
	Prefix    string `json:"prefix"`
	TargetURL string `json:"target_url"`
}

type Config struct {
	Port            string
	AllowedOrigins  []string
	ReadTimeout     time.Duration
	WriteTimeout    time.Duration
	IdleTimeout     time.Duration
	ShutdownTimeout time.Duration
	JWTSecret       string
	AuthSkipPaths   []string
	Routes          []ServiceRoute
}

type serviceEnv struct {
	Name       string
	Prefix     string
	EnvKey     string
	DefaultURL string
}

var serviceEnvs = []serviceEnv{
	{Name: "identity", Prefix: "/api/v1/identity", EnvKey: "IDENTITY_SERVICE_URL", DefaultURL: "http://localhost:8081"},
	{Name: "content", Prefix: "/api/v1/content", EnvKey: "CONTENT_SERVICE_URL", DefaultURL: "http://localhost:8082"},
	{Name: "social", Prefix: "/api/v1/social", EnvKey: "SOCIAL_SERVICE_URL", DefaultURL: "http://localhost:8083"},
	{Name: "news", Prefix: "/api/v1/news", EnvKey: "NEWS_SERVICE_URL", DefaultURL: "http://localhost:8084"},
	{Name: "ai", Prefix: "/api/v1/ai", EnvKey: "AI_SERVICE_URL", DefaultURL: "http://localhost:8085"},
	{Name: "billing", Prefix: "/api/v1/billing", EnvKey: "BILLING_SERVICE_URL", DefaultURL: "http://localhost:8086"},
	{Name: "notifications", Prefix: "/api/v1/notifications", EnvKey: "NOTIFICATION_SERVICE_URL", DefaultURL: "http://localhost:8087"},
}

func Load() (Config, error) {
	readTimeout, err := durationFromEnv("READ_TIMEOUT", 5*time.Second)
	if err != nil {
		return Config{}, err
	}

	writeTimeout, err := durationFromEnv("WRITE_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	idleTimeout, err := durationFromEnv("IDLE_TIMEOUT", 30*time.Second)
	if err != nil {
		return Config{}, err
	}

	shutdownTimeout, err := durationFromEnv("SHUTDOWN_TIMEOUT", 10*time.Second)
	if err != nil {
		return Config{}, err
	}

	routes, err := loadRoutes()
	if err != nil {
		return Config{}, err
	}

	return Config{
		Port:            stringFromEnv("PORT", "8080"),
		AllowedOrigins:  csvFromEnv("ALLOWED_ORIGINS", []string{"*"}),
		ReadTimeout:     readTimeout,
		WriteTimeout:    writeTimeout,
		IdleTimeout:     idleTimeout,
		ShutdownTimeout: shutdownTimeout,
		JWTSecret:       stringFromEnv("JWT_SECRET", "change-me"),
		AuthSkipPaths: csvFromEnv("AUTH_EXCLUDED_PATHS", []string{
			"/api/v1/_meta/routes",
			"/api/v1/identity/sign-in",
			"/api/v1/identity/sign-up",
			"/api/v1/identity/forgot-password",
		}),
		Routes: routes,
	}, nil
}

func (c Config) Addr() string {
	return ":" + c.Port
}

func loadRoutes() ([]ServiceRoute, error) {
	routes := make([]ServiceRoute, 0, len(serviceEnvs))

	for _, svc := range serviceEnvs {
		target := stringFromEnv(svc.EnvKey, svc.DefaultURL)
		if _, err := url.ParseRequestURI(target); err != nil {
			return nil, fmt.Errorf("invalid %s: %w", svc.EnvKey, err)
		}

		routes = append(routes, ServiceRoute{
			Name:      svc.Name,
			Prefix:    svc.Prefix,
			TargetURL: target,
		})
	}

	return routes, nil
}

func stringFromEnv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	return value
}

func csvFromEnv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parts := strings.Split(value, ",")
	items := make([]string, 0, len(parts))

	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			items = append(items, trimmed)
		}
	}

	if len(items) == 0 {
		return fallback
	}

	return items
}

func durationFromEnv(key string, fallback time.Duration) (time.Duration, error) {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback, nil
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return 0, fmt.Errorf("invalid %s: %w", key, err)
	}

	return duration, nil
}
