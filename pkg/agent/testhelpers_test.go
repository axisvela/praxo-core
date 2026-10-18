package agent

func answerSchema() map[string]any {
	return map[string]any{
		"type":     "object",
		"required": []any{"answer"},
		"properties": map[string]any{
			"answer": map[string]any{"type": "string", "minLength": 1},
		},
	}
}
