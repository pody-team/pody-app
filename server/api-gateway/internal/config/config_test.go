package config

import (
	"os"
	"testing"
	"time"
)

func TestLoadUsesDefaults(t *testing.T) {
	t.Setenv("PORT", "")
	t.Setenv("ALLOWED_ORIGINS", "")
	t.Setenv("READ_TIMEOUT", "")
	t.Setenv("WRITE_TIMEOUT", "")
	t.Setenv("IDLE_TIMEOUT", "")
	t.Setenv("SHUTDOWN_TIMEOUT", "")
	t.Setenv("JWT_SECRET", "")
	t.Setenv("AUTH_EXCLUDED_PATHS", "")

	for _, svc := range serviceEnvs {
		t.Setenv(svc.EnvKey, "")
	}

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() returned error: %v", err)
	}

	if cfg.Port != "8080" {
		t.Fatalf("expected default port 8080, got %s", cfg.Port)
	}

	if cfg.ReadTimeout != 5*time.Second {
		t.Fatalf("expected default read timeout 5s, got %s", cfg.ReadTimeout)
	}

	if len(cfg.AllowedOrigins) != 1 || cfg.AllowedOrigins[0] != "*" {
		t.Fatalf("expected wildcard allowed origins, got %#v", cfg.AllowedOrigins)
	}

	if len(cfg.Routes) != len(serviceEnvs) {
		t.Fatalf("expected %d routes, got %d", len(serviceEnvs), len(cfg.Routes))
	}

	if cfg.JWTSecret != "change-me" {
		t.Fatalf("expected default jwt secret, got %s", cfg.JWTSecret)
	}

	if len(cfg.AuthSkipPaths) != 0 {
		t.Fatalf("expected no default auth skip paths, got %#v", cfg.AuthSkipPaths)
	}
}

func TestLoadOverridesValues(t *testing.T) {
	t.Setenv("PORT", "9090")
	t.Setenv("ALLOWED_ORIGINS", "http://localhost:3000, https://app.pody.local")
	t.Setenv("READ_TIMEOUT", "7s")
	t.Setenv("JWT_SECRET", "super-secret")
	t.Setenv("AUTH_EXCLUDED_PATHS", "/api/v1/_meta/routes,/api/v1/public")
	t.Setenv("SOCIAL_SERVICE_URL", "http://localhost:9003")
	t.Setenv("IDENTITY_SERVICE_URL", "http://localhost:9001")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() returned error: %v", err)
	}

	if cfg.Port != "9090" {
		t.Fatalf("expected port 9090, got %s", cfg.Port)
	}

	if cfg.ReadTimeout != 7*time.Second {
		t.Fatalf("expected read timeout 7s, got %s", cfg.ReadTimeout)
	}

	if cfg.JWTSecret != "super-secret" {
		t.Fatalf("expected jwt secret to be overridden, got %s", cfg.JWTSecret)
	}

	if got, want := len(cfg.AllowedOrigins), 2; got != want {
		t.Fatalf("expected %d allowed origins, got %d", want, got)
	}

	if got, want := len(cfg.AuthSkipPaths), 2; got != want {
		t.Fatalf("expected %d auth skip paths, got %d", want, got)
	}

	foundSocial := false
	foundContentPublic := false
	foundContentProtected := false
	foundIdentityPublic := false
	foundIdentityProtected := false
	foundAIProtected := false
	for _, route := range cfg.Routes {
		if route.Name == "social" {
			foundSocial = true
			if route.TargetURL != "http://localhost:9003" {
				t.Fatalf("expected social target to be overridden, got %s", route.TargetURL)
			}
		}

		if route.Name == "identity-public" {
			foundIdentityPublic = true
			if route.TargetURL != "http://localhost:9001/api/v1/public/identity" {
				t.Fatalf("unexpected public identity target %s", route.TargetURL)
			}
		}

		if route.Name == "content-public" {
			foundContentPublic = true
			if route.TargetURL != "http://localhost:8082/api/v1/public/content" {
				t.Fatalf("unexpected public content target %s", route.TargetURL)
			}
		}

		if route.Name == "content" {
			foundContentProtected = true
			if route.TargetURL != "http://localhost:8082/api/v1/content" {
				t.Fatalf("unexpected protected content target %s", route.TargetURL)
			}
		}

		if route.Name == "identity" {
			foundIdentityProtected = true
			if route.TargetURL != "http://localhost:9001/api/v1/identity" {
				t.Fatalf("unexpected protected identity target %s", route.TargetURL)
			}
		}

		if route.Name == "ai" {
			foundAIProtected = true
			if route.TargetURL != "http://localhost:8085/api/v1/ai" {
				t.Fatalf("unexpected ai target %s", route.TargetURL)
			}
		}
	}

	if !foundSocial {
		t.Fatal("social route was not found")
	}

	if !foundIdentityPublic || !foundIdentityProtected {
		t.Fatal("identity routes were not configured correctly")
	}

	if !foundContentPublic || !foundContentProtected {
		t.Fatal("content routes were not configured correctly")
	}

	if !foundAIProtected {
		t.Fatal("ai route was not configured correctly")
	}
}

func TestLoadRejectsInvalidURL(t *testing.T) {
	t.Setenv("NEWS_SERVICE_URL", "://bad-url")

	_, err := Load()
	if err == nil {
		t.Fatal("expected invalid URL error, got nil")
	}
}

func TestMain(m *testing.M) {
	code := m.Run()
	os.Exit(code)
}
