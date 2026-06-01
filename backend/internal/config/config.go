package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	Port           string
	DatabaseURL    string
	RedisURL       string
	JWTSecret      string
	AdminJWTSecret string
	Env            string
	UploadDir      string
	PublicBaseURL  string
}

func LoadConfig() (*Config, error) {
	// Try to load .env file if it exists, but don't fail if it doesn't
	_ = godotenv.Load()

	port := getEnv("PORT", "8080")
	dbURL := getEnv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/moonlit_stories?sslmode=disable")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379/0")
	jwtSecret := getEnv("JWT_SECRET", "moonlit-stories-jwt-secret-key-123456")
	adminJWTSecret := getEnv("ADMIN_JWT_SECRET", "moonlit-stories-admin-secret-key-654321")
	env := getEnv("ENV", "development")
	uploadDir := getEnv("UPLOAD_DIR", "uploads")
	publicBaseURL := getEnv("PUBLIC_BASE_URL", "")

	return &Config{
		Port:           port,
		DatabaseURL:    dbURL,
		RedisURL:       redisURL,
		JWTSecret:      jwtSecret,
		AdminJWTSecret: adminJWTSecret,
		Env:            env,
		UploadDir:      uploadDir,
		PublicBaseURL:  publicBaseURL,
	}, nil
}

func getEnv(key, defaultVal string) string {
	if val, ok := os.LookupEnv(key); ok {
		return val
	}
	return defaultVal
}
