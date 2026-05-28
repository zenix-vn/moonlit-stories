package auth

import (
	"testing"

	"github.com/golang-jwt/jwt/v5"
)

func TestGenerateAndParseUserToken(t *testing.T) {
	secret := "test-secret-key-123456"
	userID := "550e8400-e29b-41d4-a716-446655440000"

	// 1. Generate Token
	tokenString, err := GenerateUserToken(userID, secret)
	if err != nil {
		t.Fatalf("Expected no error on generating token, got: %v", err)
	}

	if tokenString == "" {
		t.Fatal("Expected signed token string, got empty")
	}

	// 2. Parse and Validate Token
	claims := &UserClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})

	if err != nil {
		t.Fatalf("Expected parsing to succeed, got: %v", err)
	}

	if !token.Valid {
		t.Fatal("Expected parsed token to be valid")
	}

	if claims.UserID != userID {
		t.Errorf("Expected User ID %s, got: %s", userID, claims.UserID)
	}
}

func TestGenerateAndParseAdminToken(t *testing.T) {
	secret := "test-admin-secret-key"
	adminID := "admin-user-uuid"
	roles := []string{"editor", "writer"}

	// 1. Generate Admin Token
	tokenString, err := GenerateAdminToken(adminID, roles, secret)
	if err != nil {
		t.Fatalf("Expected no error on generating admin token, got: %v", err)
	}

	// 2. Parse and Validate
	claims := &AdminClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	})

	if err != nil {
		t.Fatalf("Expected parsing to succeed, got: %v", err)
	}

	if !token.Valid {
		t.Fatal("Expected parsed token to be valid")
	}

	if claims.AdminUserID != adminID {
		t.Errorf("Expected Admin User ID %s, got: %s", adminID, claims.AdminUserID)
	}

	if len(claims.Roles) != 2 || claims.Roles[0] != "editor" || claims.Roles[1] != "writer" {
		t.Errorf("Expected roles %v, got: %v", roles, claims.Roles)
	}
}

func TestInvalidSecretTokenParsing(t *testing.T) {
	secret := "secret-key"
	wrongSecret := "wrong-secret-key"
	userID := "user-uuid"

	tokenString, _ := GenerateUserToken(userID, secret)

	claims := &UserClaims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(wrongSecret), nil
	})

	if err == nil {
		t.Fatal("Expected error when parsing token with incorrect secret, got nil")
	}

	if token != nil && token.Valid {
		t.Fatal("Expected token to be invalid when parsed with incorrect secret")
	}
}
