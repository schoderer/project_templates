package main

import (
	"io"
	"net/http/httptest"
	"testing"
)

func get(t *testing.T, path string) (int, string) {
	t.Helper()
	recorder := httptest.NewRecorder()
	newMux().ServeHTTP(recorder, httptest.NewRequest("GET", path, nil))
	body, _ := io.ReadAll(recorder.Result().Body)
	return recorder.Code, string(body)
}

func TestHealth(t *testing.T) {
	if code, body := get(t, "/health"); code != 200 || body != "ok" {
		t.Fatalf("got %d %q", code, body)
	}
}

func TestHello(t *testing.T) {
	if code, body := get(t, "/hello/nix"); code != 200 || body != "Hello, nix!" {
		t.Fatalf("got %d %q", code, body)
	}
}
