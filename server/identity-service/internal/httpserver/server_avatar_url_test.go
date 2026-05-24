package httpserver

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNormalizeOutgoingAvatarURLRewritesInternalMinIOHost(t *testing.T) {
	server := &Server{minioBucketName: "identity-avatars"}
	request := httptest.NewRequest(http.MethodGet, "http://identity-service:8081/api/v1/identity/me", nil)
	request.Header.Set("X-Forwarded-Host", "laihieu2714.ddns.net")
	request.Header.Set("X-Forwarded-Proto", "https")

	got := server.normalizeOutgoingAvatarURL(
		request,
		"http://minio:9000/identity-avatars/avatars/user-1/avatar.png",
	)

	want := "https://laihieu2714.ddns.net/minio/identity-avatars/avatars/user-1/avatar.png"
	if got != want {
		t.Fatalf("expected public avatar url %q, got %q", want, got)
	}
}

func TestNormalizeOutgoingAvatarURLPrefixesBucketPathOnPublicHost(t *testing.T) {
	server := &Server{minioBucketName: "identity-avatars"}
	request := httptest.NewRequest(http.MethodGet, "https://laihieu2714.ddns.net/api/v1/identity/me", nil)

	got := server.normalizeOutgoingAvatarURL(
		request,
		"https://laihieu2714.ddns.net/identity-avatars/avatars/user-1/avatar.png",
	)

	want := "https://laihieu2714.ddns.net/minio/identity-avatars/avatars/user-1/avatar.png"
	if got != want {
		t.Fatalf("expected bucket path to be prefixed with /minio, got %q", got)
	}
}

func TestNormalizeOutgoingAvatarURLKeepsAlreadyPublicMinIOURL(t *testing.T) {
	server := &Server{minioBucketName: "identity-avatars"}
	request := httptest.NewRequest(http.MethodGet, "https://laihieu2714.ddns.net/api/v1/identity/me", nil)

	raw := "https://laihieu2714.ddns.net/minio/identity-avatars/avatars/user-1/avatar.png"
	got := server.normalizeOutgoingAvatarURL(request, raw)
	if got != raw {
		t.Fatalf("expected already public minio url to stay unchanged, got %q", got)
	}
}
