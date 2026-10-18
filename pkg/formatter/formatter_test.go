package formatter

import "testing"

func TestListIsNotEmpty(t *testing.T) {
	if len(List()) == 0 {
		t.Fatal("expected registered formatters")
	}
}

func TestCommandFields(t *testing.T) {
	f := Formatter{Command: "gofmt -w $FILE"}
	fields := f.CommandFields()
	if len(fields) != 3 || fields[0] != "gofmt" || fields[2] != "$FILE" {
		t.Fatalf("fields = %+v", fields)
	}
}
