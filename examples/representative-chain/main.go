package main

import (
	"context"
	"fmt"
	"os"
	"time"
)

func main() {
	modelName := os.Getenv("PRAXO_OLLAMA_MODEL")
	if modelName == "" {
		fmt.Fprintln(os.Stderr, "set PRAXO_OLLAMA_MODEL, for example qwen3.5:4b")
		os.Exit(2)
	}
	baseURL := os.Getenv("PRAXO_OLLAMA_BASE_URL")
	if baseURL == "" {
		baseURL = "http://127.0.0.1:11434/v1"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	result, err := runChain(ctx, config{
		BaseURL: baseURL,
		Model:   modelName,
		APIKey:  os.Getenv("PRAXO_OLLAMA_API_KEY"),
	})
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println("output:", result.Output)
	fmt.Println("effects:", result.Effects)
	fmt.Println("child calls:", result.ChildCalls)
	fmt.Println("spans:", len(result.Spans))
	fmt.Println("events:", len(result.Events))
	fmt.Println("denied effects:", result.DeniedEffect)
}
