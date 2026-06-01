package ai

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type AIHandler struct {
	DB *sql.DB
}

// Request and Response Models

type GenerateOutlineRequest struct {
	Prompt string `json:"prompt"`
}

type Character struct {
	Name        string `json:"name"`
	Role        string `json:"role"`
	Description string `json:"description"`
}

type GeneratedOutline struct {
	Title       string      `json:"title"`
	Hook        string      `json:"hook"`
	Description string      `json:"description"`
	Outline     string      `json:"outline"`
	Characters  []Character `json:"characters"`
	Setting     string      `json:"setting"`
}

type SaveOutlineRequest struct {
	Title       string      `json:"title"`
	Hook        string      `json:"hook"`
	Description string      `json:"description"`
	Outline     string      `json:"outline"`
	Characters  []Character `json:"characters"`
	Setting     string      `json:"setting"`
}

type EpisodeSummary struct {
	EpisodeNumber int    `json:"episode_number"`
	Title         string `json:"title"`
	Summary       string `json:"summary"`
}

type GeneratedEpisodeResponse struct {
	Title   string `json:"title"`
	Content string `json:"content"`
	Summary string `json:"summary"`
}

type GenerateEpisodeRequest struct {
	Guidance string `json:"guidance,omitempty"` // Optional instructions for this chapter
}

// OpenRouter API Structs

type OpenRouterMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type OpenRouterResponseFormat struct {
	Type string `json:"type"`
}

type OpenRouterRequest struct {
	Model          string                    `json:"model"`
	Messages       []OpenRouterMessage       `json:"messages"`
	ResponseFormat *OpenRouterResponseFormat `json:"response_format,omitempty"`
	MaxTokens      int                       `json:"max_tokens,omitempty"`
}

type OpenRouterChoice struct {
	Message struct {
		Content string `json:"content"`
	} `json:"message"`
}

type OpenRouterResponse struct {
	Choices []OpenRouterChoice `json:"choices"`
	Error   *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// Helper to call OpenRouter
func callOpenRouter(db *sql.DB, systemPrompt, userPrompt string) (string, error) {
	apiKey := os.Getenv("OPENROUTER_API_KEY")
	if apiKey == "" && db != nil {
		// Fallback: check db app_configs for openrouter_api_key inside system_config json
		var value []byte
		err := db.QueryRow("SELECT value FROM app_configs WHERE key = 'system_config'").Scan(&value)
		if err == nil {
			var parsed map[string]interface{}
			if err := json.Unmarshal(value, &parsed); err == nil {
				if keyVal, ok := parsed["openrouter_api_key"].(string); ok && keyVal != "" {
					apiKey = keyVal
				}
			}
		}
	}

	if apiKey == "" {
		return "", errors.New("OPENROUTER_API_KEY is not configured (please set it as an environment variable or configure it in Admin Settings)")
	}

	model := os.Getenv("OPENROUTER_MODEL")
	if model == "" {
		model = "meta-llama/llama-3.1-70b-instruct"
	}

	reqBody := OpenRouterRequest{
		Model: model,
		Messages: []OpenRouterMessage{
			{Role: "system", Content: systemPrompt},
			{Role: "user", Content: userPrompt},
		},
		ResponseFormat: &OpenRouterResponseFormat{Type: "json_object"},
		MaxTokens:      4096,
	}

	jsonBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to serialize request: %w", err)
	}

	req, err := http.NewRequestWithContext(context.Background(), "POST", "https://openrouter.ai/api/v1/chat/completions", bytes.NewBuffer(jsonBytes))
	if err != nil {
		return "", fmt.Errorf("failed to create http request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("HTTP-Referer", "https://moonlit-stories.com")
	req.Header.Set("X-Title", "Moonlit Stories Admin")

	client := &http.Client{Timeout: 120 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("http request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		var errData map[string]interface{}
		_ = json.NewDecoder(resp.Body).Decode(&errData)
		return "", fmt.Errorf("openrouter api returned status %d: %v", resp.StatusCode, errData)
	}

	var apiResp OpenRouterResponse
	if err := json.NewDecoder(resp.Body).Decode(&apiResp); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	if apiResp.Error != nil {
		return "", fmt.Errorf("openrouter returned error: %s", apiResp.Error.Message)
	}

	if len(apiResp.Choices) == 0 {
		return "", errors.New("no completion choices returned from openrouter")
	}

	return apiResp.Choices[0].Message.Content, nil
}

// cleanJSONString cleans up markdown code blocks if the model wrapped the JSON response
func cleanJSONString(s string) string {
	s = strings.TrimSpace(s)
	// Remove markdown wrapping if present
	if strings.HasPrefix(s, "```json") {
		s = strings.TrimPrefix(s, "```json")
		s = strings.TrimSuffix(s, "```")
	} else if strings.HasPrefix(s, "```") {
		s = strings.TrimPrefix(s, "```")
		s = strings.TrimSuffix(s, "```")
	}
	return strings.TrimSpace(s)
}

// GenerateOutline generates a story idea, characters, outline and setting
func (h *AIHandler) GenerateOutline(c echo.Context) error {
	var req GenerateOutlineRequest
	if err := c.Bind(&req); err != nil || req.Prompt == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body, prompt is required"})
	}

	systemPrompt := `You are an expert novel editor and developer for serialized mobile story apps.
Your task is to outline a compelling serialized romance or fantasy novel based on the user's brief prompt.
You MUST output your response in strict JSON format matching this schema:
{
  "title": "Compelling Title",
  "hook": "A short 1-sentence hook that grab readers",
  "description": "A 2-3 sentence synopsis for the story detail view",
  "outline": "A comprehensive plot outline/synopsis summarizing the full arc of the story, key conflicts, and milestones",
  "characters": [
    {
      "name": "Character Name",
      "role": "Main Lead / Love Interest / Antagonist / Support",
      "description": "Short bio, personality traits, and motivation"
    }
  ],
  "setting": "World rules, descriptions of key locations, and atmospheric details"
}
Output only the JSON object. Do not wrap in markdown or add explanations.`

	completion, err := callOpenRouter(h.DB, systemPrompt, req.Prompt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to generate outline: " + err.Error()})
	}

	completion = cleanJSONString(completion)
	var outline GeneratedOutline
	if err := json.Unmarshal([]byte(completion), &outline); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, map[string]interface{}{
			"raw_completion": completion,
			"error":          "Failed to parse outline JSON: " + err.Error(),
		})
	}

	return c.JSON(http.StatusOK, outline)
}

// SaveOutline creates the story and saves its AI context
func (h *AIHandler) SaveOutline(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	var req SaveOutlineRequest
	if err := c.Bind(&req); err != nil || req.Title == "" {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid request body, title is required"})
	}

	ctx := c.Request().Context()
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	// 1. Create slug
	slug := fmt.Sprintf("ai-%d-%s", time.Now().Unix(), uuid.New().String()[:6])

	// 2. Insert into stories table
	storyID := uuid.New()
	_, err = tx.ExecContext(ctx, `
		INSERT INTO stories (id, title, slug, description, hook, language, status, free_episode_count, default_coin_price, total_episodes, created_by, updated_by)
		VALUES ($1, $2, $3, $4, $5, 'en', 'draft', 3, 20, 0, $6, $6)
	`, storyID, req.Title, slug, req.Description, req.Hook, adminID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to insert story: " + err.Error()})
	}

	// 3. Serialize characters list to json
	charBytes, err := json.Marshal(req.Characters)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to serialize characters list"})
	}

	// 4. Create AI Context
	_, err = tx.ExecContext(ctx, `
		INSERT INTO story_ai_contexts (story_id, outline, characters, setting, episode_summaries, created_at, updated_at)
		VALUES ($1, $2, $3, $4, '[]'::jsonb, now(), now())
	`, storyID, req.Outline, charBytes, req.Setting)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to save AI context: " + err.Error()})
	}

	// 5. Audit Log
	_, _ = tx.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, created_at)
		VALUES ($1, 'ai_generate_story', 'stories', $2, now())
	`, adminID, storyID)

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "transaction commit failed"})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"story_id": storyID.String(),
		"title":    req.Title,
		"slug":     slug,
	})
}

// GetAIContext fetches context for a story
func (h *AIHandler) GetAIContext(c echo.Context) error {
	storyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	ctx := c.Request().Context()
	var outline, setting string
	var charactersRaw, summariesRaw []byte

	err = h.DB.QueryRowContext(ctx, `
		SELECT outline, characters, setting, episode_summaries
		FROM story_ai_contexts WHERE story_id = $1
	`, storyID).Scan(&outline, &charactersRaw, &setting, &summariesRaw)

	if err == sql.ErrNoRows {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "AI context not found for this story"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query AI context"})
	}

	var characters []Character
	var summaries []EpisodeSummary

	_ = json.Unmarshal(charactersRaw, &characters)
	_ = json.Unmarshal(summariesRaw, &summaries)

	return c.JSON(http.StatusOK, map[string]interface{}{
		"story_id":          storyID.String(),
		"outline":           outline,
		"characters":        characters,
		"setting":           setting,
		"episode_summaries": summaries,
	})
}

// GenerateNextEpisode uses previous summaries to generate the next chapter dynamically
func (h *AIHandler) GenerateNextEpisode(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	storyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	var req GenerateEpisodeRequest
	_ = c.Bind(&req) // Guidance is optional

	ctx := c.Request().Context()

	// 1. Fetch Story Meta
	var storyTitle string
	var freeChapters int
	err = h.DB.QueryRowContext(ctx, "SELECT title, free_episode_count FROM stories WHERE id = $1", storyID).Scan(&storyTitle, &freeChapters)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "story not found"})
	}

	// 2. Fetch AI Context details
	var outline, setting string
	var charactersRaw, summariesRaw []byte
	err = h.DB.QueryRowContext(ctx, `
		SELECT outline, characters, setting, episode_summaries
		FROM story_ai_contexts WHERE story_id = $1
	`, storyID).Scan(&outline, &charactersRaw, &setting, &summariesRaw)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "AI Context not initialized for this story"})
	}

	var summaries []EpisodeSummary
	_ = json.Unmarshal(summariesRaw, &summaries)

	// 3. Determine next episode number
	var nextEpisodeNum int
	err = h.DB.QueryRowContext(ctx, "SELECT COALESCE(MAX(episode_number), 0) + 1 FROM episodes WHERE story_id = $1", storyID).Scan(&nextEpisodeNum)
	if err != nil {
		nextEpisodeNum = len(summaries) + 1
	}

	// 4. Construct AI System & User Prompts
	systemPrompt := `You are an expert ghostwriter of serialized romance, thriller, and werewolf books for mobile reader apps.
Your chapters must be highly engaging, filled with dynamic dialogue, sensory descriptions, and emotional tension.
You MUST write a complete episode based on the provided story context, characters, setting, and previous episode summaries.

Your response MUST be a single JSON object with EXACTLY three fields:
{
  "title": "Title of the Episode",
  "content": "Plain text containing the full text of the chapter. Use double newlines (\\n\\n) to separate paragraphs. Word count must be between 1000 and 1500 words.",
  "summary": "A concise 1-paragraph summary (50-80 words) describing the major plot points that occurred in this episode. Do not spoil future chapters."
}
Output only the JSON object. Do not wrap in markdown or add explanations.`

	// Construct past episodes summary block for chronological context
	pastSummariesText := ""
	if len(summaries) > 0 {
		pastSummariesText += "\n### CHRONOLOGICAL HISTORY OF PREVIOUS EPISODES:\n"
		for _, s := range summaries {
			pastSummariesText += fmt.Sprintf("- Episode %d: %s\n  Summary: %s\n", s.EpisodeNumber, s.Title, s.Summary)
		}
	} else {
		pastSummariesText = "\nThis is the very first chapter (Episode 1) of the story."
	}

	userPrompt := fmt.Sprintf(`Story Title: %s
Story Outline: %s
Characters Profile: %s
World Setting: %s
%s

You are writing Episode %d.
`, storyTitle, outline, string(charactersRaw), setting, pastSummariesText, nextEpisodeNum)

	if req.Guidance != "" {
		userPrompt += fmt.Sprintf("\nSpecial instructions/plot direction for this episode: %s\n", req.Guidance)
	} else {
		userPrompt += "\nContinue the plot naturally from the last event, developing the relationship or conflicts, and end the episode with a minor cliffhanger.\n"
	}

	// 5. Call OpenRouter
	completion, err := callOpenRouter(h.DB, systemPrompt, userPrompt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "OpenRouter completion failed: " + err.Error()})
	}

	completion = cleanJSONString(completion)
	var genEp GeneratedEpisodeResponse
	if err := json.Unmarshal([]byte(completion), &genEp); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, map[string]interface{}{
			"raw_completion": completion,
			"error":          "Failed to parse episode JSON: " + err.Error(),
		})
	}

	// 6. Save Episode and Context updates in Transaction
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	epID := uuid.New()
	isFree := nextEpisodeNum <= freeChapters
	coinPrice := 20
	if isFree {
		coinPrice = 0
	}
	previewText := genEp.Content
	if len(previewText) > 300 {
		previewText = previewText[:300] + "..."
	}

	// Save Episode
	_, err = tx.ExecContext(ctx, `
		INSERT INTO episodes (id, story_id, episode_number, title, content_text, is_free, coin_price, preview_text, status, created_by, updated_by, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'draft', $9, $9, now(), now())
	`, epID, storyID, nextEpisodeNum, genEp.Title, genEp.Content, isFree, coinPrice, previewText, adminID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to insert episode: " + err.Error()})
	}

	// Update Story count
	_, _ = tx.ExecContext(ctx, "UPDATE stories SET total_episodes = (SELECT COUNT(*) FROM episodes WHERE story_id = $1 AND status = 'published') WHERE id = $1", storyID)

	// Append summary to context
	newSummary := EpisodeSummary{
		EpisodeNumber: nextEpisodeNum,
		Title:         genEp.Title,
		Summary:       genEp.Summary,
	}
	summaries = append(summaries, newSummary)
	newSummariesRaw, err := json.Marshal(summaries)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to serialize updated summaries"})
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE story_ai_contexts
		SET episode_summaries = $1, updated_at = now()
		WHERE story_id = $2
	`, newSummariesRaw, storyID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update AI context: " + err.Error()})
	}

	// Audit Log
	_, _ = tx.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, created_at)
		VALUES ($1, 'ai_generate_episode', 'episodes', $2, now())
	`, adminID, epID)

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "transaction commit failed"})
	}

	return c.JSON(http.StatusCreated, map[string]interface{}{
		"id":             epID.String(),
		"episode_number": nextEpisodeNum,
		"title":          genEp.Title,
		"content":        genEp.Content,
		"summary":        genEp.Summary,
	})
}

// RegenerateLastEpisode rewrites/regenerates the last episode using editor feedback/guidance
func (h *AIHandler) RegenerateLastEpisode(c echo.Context) error {
	adminID, _ := uuid.Parse(c.Get("admin_id").(string))
	storyID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "invalid story ID"})
	}

	var req GenerateEpisodeRequest
	_ = c.Bind(&req) // Guidance is optional feedback

	ctx := c.Request().Context()

	// 1. Fetch Story Meta
	var storyTitle string
	err = h.DB.QueryRowContext(ctx, "SELECT title FROM stories WHERE id = $1", storyID).Scan(&storyTitle)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "story not found"})
	}

	// 2. Find the last episode ID, number and status
	var lastEpID uuid.UUID
	var lastEpisodeNum int
	var lastStatus string
	err = h.DB.QueryRowContext(ctx, `
		SELECT id, episode_number, status FROM episodes
		WHERE story_id = $1 AND episode_number = (SELECT COALESCE(MAX(episode_number), 0) FROM episodes WHERE story_id = $1)
	`, storyID).Scan(&lastEpID, &lastEpisodeNum, &lastStatus)
	if err == sql.ErrNoRows || lastEpisodeNum == 0 {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "No episodes exist for this story to regenerate"})
	} else if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to query last episode"})
	}

	// 3. Fetch AI Context details
	var outline, setting string
	var charactersRaw, summariesRaw []byte
	err = h.DB.QueryRowContext(ctx, `
		SELECT outline, characters, setting, episode_summaries
		FROM story_ai_contexts WHERE story_id = $1
	`, storyID).Scan(&outline, &charactersRaw, &setting, &summariesRaw)
	if err != nil {
		return c.JSON(http.StatusNotFound, map[string]string{"error": "AI Context not initialized for this story"})
	}

	var summaries []EpisodeSummary
	_ = json.Unmarshal(summariesRaw, &summaries)

	// To regenerate, we construct past episode summaries excluding the last one!
	var prevSummaries []EpisodeSummary
	for _, s := range summaries {
		if s.EpisodeNumber < lastEpisodeNum {
			prevSummaries = append(prevSummaries, s)
		}
	}

	// 4. Construct AI System & User Prompts
	systemPrompt := `You are an expert ghostwriter of serialized romance, thriller, and werewolf books for mobile reader apps.
Your chapters must be highly engaging, filled with dynamic dialogue, sensory descriptions, and emotional tension.
You MUST write a complete episode based on the provided story context, characters, setting, and previous episode summaries.

Your response MUST be a single JSON object with EXACTLY three fields:
{
  "title": "Title of the Episode",
  "content": "Plain text containing the full text of the chapter. Use double newlines (\\n\\n) to separate paragraphs. Word count must be between 1000 and 1500 words.",
  "summary": "A concise 1-paragraph summary (50-80 words) describing the major plot points that occurred in this episode. Do not spoil future chapters."
}
Output only the JSON object. Do not wrap in markdown or add explanations.`

	// Construct past summaries log up to N-1
	pastSummariesText := ""
	if len(prevSummaries) > 0 {
		pastSummariesText += "\n### CHRONOLOGICAL HISTORY OF PREVIOUS EPISODES:\n"
		for _, s := range prevSummaries {
			pastSummariesText += fmt.Sprintf("- Episode %d: %s\n  Summary: %s\n", s.EpisodeNumber, s.Title, s.Summary)
		}
	} else {
		pastSummariesText = "\nThis is the very first chapter (Episode 1) of the story."
	}

	userPrompt := fmt.Sprintf(`Story Title: %s
Story Outline: %s
Characters Profile: %s
World Setting: %s
%s

You are rewriting/regenerating Episode %d.
`, storyTitle, outline, string(charactersRaw), setting, pastSummariesText, lastEpisodeNum)

	if req.Guidance != "" {
		userPrompt += fmt.Sprintf("\nIMPORTANT Feedback/Instructions for rewriting this chapter: %s\n", req.Guidance)
	} else {
		userPrompt += "\nRewrite the chapter, making it highly engaging, developing characters, and ending on a suspenseful note.\n"
	}

	// 5. Call OpenRouter
	completion, err := callOpenRouter(h.DB, systemPrompt, userPrompt)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "OpenRouter completion failed: " + err.Error()})
	}

	completion = cleanJSONString(completion)
	var genEp GeneratedEpisodeResponse
	if err := json.Unmarshal([]byte(completion), &genEp); err != nil {
		return c.JSON(http.StatusUnprocessableEntity, map[string]interface{}{
			"raw_completion": completion,
			"error":          "Failed to parse episode JSON: " + err.Error(),
		})
	}

	// 6. Update Episode and Context in Transaction
	tx, err := h.DB.BeginTx(ctx, nil)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to start transaction"})
	}
	defer tx.Rollback()

	previewText := genEp.Content
	if len(previewText) > 300 {
		previewText = previewText[:300] + "..."
	}

	// Update Episode
	_, err = tx.ExecContext(ctx, `
		UPDATE episodes
		SET title = $1, content_text = $2, preview_text = $3, updated_by = $4, updated_at = now()
		WHERE id = $5
	`, genEp.Title, genEp.Content, previewText, adminID, lastEpID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update episode: " + err.Error()})
	}

	// Rebuild the summaries list with the updated summary for this episode
	var updatedSummaries []EpisodeSummary
	found := false
	for _, s := range summaries {
		if s.EpisodeNumber == lastEpisodeNum {
			s.Title = genEp.Title
			s.Summary = genEp.Summary
			found = true
		}
		updatedSummaries = append(updatedSummaries, s)
	}
	if !found {
		// Fallback if not found in context logs for some reason
		updatedSummaries = append(prevSummaries, EpisodeSummary{
			EpisodeNumber: lastEpisodeNum,
			Title:         genEp.Title,
			Summary:       genEp.Summary,
		})
	}

	newSummariesRaw, err := json.Marshal(updatedSummaries)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to serialize updated summaries"})
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE story_ai_contexts
		SET episode_summaries = $1, updated_at = now()
		WHERE story_id = $2
	`, newSummariesRaw, storyID)
	if err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "failed to update AI context: " + err.Error()})
	}

	// Audit Log
	_, _ = tx.ExecContext(ctx, `
		INSERT INTO admin_audit_logs (admin_user_id, action, entity_type, entity_id, created_at)
		VALUES ($1, 'ai_regenerate_episode', 'episodes', $2, now())
	`, adminID, lastEpID)

	if err := tx.Commit(); err != nil {
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "transaction commit failed"})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"id":             lastEpID.String(),
		"episode_number": lastEpisodeNum,
		"title":          genEp.Title,
		"content":        genEp.Content,
		"summary":        genEp.Summary,
	})
}
