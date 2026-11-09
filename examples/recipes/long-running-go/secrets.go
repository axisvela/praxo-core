package longrunning

import (
	"errors"
	"os"
	"strings"
)

type SecretSource interface {
	Value() (string, error)
}

type StaticSecret string

func (s StaticSecret) Value() (string, error) {
	if s == "" {
		return "", errors.New("empty secret")
	}
	return string(s), nil
}

type FileSecret struct {
	path string
}

func NewFileSecret(path string) (*FileSecret, error) {
	secret := &FileSecret{path: path}
	if _, err := secret.Value(); err != nil {
		return nil, err
	}
	return secret, nil
}

func (s *FileSecret) Value() (string, error) {
	data, err := os.ReadFile(s.path)
	if err != nil {
		return "", err
	}
	value := strings.TrimSpace(string(data))
	if value == "" {
		return "", errors.New("empty secret file")
	}
	return value, nil
}
