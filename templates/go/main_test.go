package main

import "testing"

func TestGreeting(t *testing.T) {
	if got := greeting(); got != "Hello World!" {
		t.Errorf("greeting() = %q", got)
	}
}
