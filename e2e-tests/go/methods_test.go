package e2e_test

import (
	"testing"

	methods "e2e-test/skirout/methods"
)

func TestMyProcedure(t *testing.T) {
	m := methods.MyProcedure()
	if got := m.Name(); got != "MyProcedure" {
		t.Errorf("Name() = %q, want MyProcedure", got)
	}
	if got := m.Number(); got != 674706602 {
		t.Errorf("Number() = %d, want 674706602", got)
	}
	if got := m.Doc(); got != "My procedure" {
		t.Errorf("Doc() = %q, want My procedure", got)
	}
}

func TestWithExplicitNumber(t *testing.T) {
	m := methods.WithExplicitNumber()
	if got := m.Name(); got != "WithExplicitNumber" {
		t.Errorf("Name() = %q, want WithExplicitNumber", got)
	}
	if got := m.Number(); got != 3 {
		t.Errorf("Number() = %d, want 3", got)
	}
	if got := m.Doc(); got != "" {
		t.Errorf("Doc() = %q, want empty", got)
	}
}

func TestTrue(t *testing.T) {
	m := methods.True()
	if got := m.Name(); got != "True" {
		t.Errorf("Name() = %q, want True", got)
	}
	if got := m.Number(); got != 78901 {
		t.Errorf("Number() = %d, want 78901", got)
	}
	if got := m.Doc(); got != "" {
		t.Errorf("Doc() = %q, want empty", got)
	}
}

func TestMethod_SerializersAreNonNil(t *testing.T) {
	m := methods.MyProcedure()
	if m.RequestSerializer().TypeDescriptor() == nil {
		t.Error("RequestSerializer().TypeDescriptor() is nil")
	}
	if m.ResponseSerializer().TypeDescriptor() == nil {
		t.Error("ResponseSerializer().TypeDescriptor() is nil")
	}
}
