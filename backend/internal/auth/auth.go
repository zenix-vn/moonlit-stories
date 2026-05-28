package auth

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
)

type UserClaims struct {
	UserID string `json:"user_id"`
	jwt.RegisteredClaims
}

type AdminClaims struct {
	AdminUserID string   `json:"admin_id"`
	Roles       []string `json:"roles"`
	jwt.RegisteredClaims
}

// GenerateUserToken generates a JWT for a mobile app user
func GenerateUserToken(userID string, secret string) (string, error) {
	claims := UserClaims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)), // 30 days
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// GenerateAdminToken generates a JWT for an admin panel user
func GenerateAdminToken(adminID string, roles []string, secret string) (string, error) {
	claims := AdminClaims{
		AdminUserID: adminID,
		Roles:       roles,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)), // 24 hours
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// UserAuthMiddleware validates JWTs for mobile app requests
func UserAuthMiddleware(jwtSecret string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "missing authorization header"})
			}

			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid token format"})
			}

			tokenString := parts[1]
			claims := &UserClaims{}

			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				return []byte(jwtSecret), nil
			})

			if err != nil || !token.Valid {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid or expired token"})
			}

			c.Set("user_id", claims.UserID)
			return next(c)
		}
	}
}

// AdminAuthMiddleware validates JWTs for admin panel requests
func AdminAuthMiddleware(jwtSecret string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			authHeader := c.Request().Header.Get("Authorization")
			if authHeader == "" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "missing admin authorization header"})
			}

			parts := strings.Split(authHeader, " ")
			if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid token format"})
			}

			tokenString := parts[1]
			claims := &AdminClaims{}

			token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
				return []byte(jwtSecret), nil
			})

			if err != nil || !token.Valid {
				return c.JSON(http.StatusUnauthorized, map[string]string{"error": "invalid or expired admin token"})
			}

			c.Set("admin_id", claims.AdminUserID)
			c.Set("admin_roles", claims.Roles)
			return next(c)
		}
	}
}

// HasRoleCheck checks if the authenticated admin has the required role
func HasRoleCheck(requiredRoles ...string) echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			rolesInterface := c.Get("admin_roles")
			if rolesInterface == nil {
				return c.JSON(http.StatusForbidden, map[string]string{"error": "forbidden - no roles found"})
			}

			userRoles := rolesInterface.([]string)
			for _, r := range userRoles {
				if r == "super_admin" {
					return next(c) // Super admin has access to everything
				}
				for _, req := range requiredRoles {
					if r == req {
						return next(c)
					}
				}
			}

			return c.JSON(http.StatusForbidden, map[string]string{"error": "forbidden - insufficient permissions"})
		}
	}
}

// Helper to get authenticated User ID from context
func GetUserID(c echo.Context) (uuid.UUID, error) {
	val := c.Get("user_id")
	if val == nil {
		return uuid.Nil, errors.New("user ID not found in context")
	}
	idStr, ok := val.(string)
	if !ok {
		return uuid.Nil, errors.New("invalid user ID type in context")
	}
	return uuid.Parse(idStr)
}

// Helper to check and log login event
func LogLoginEvent(ctx context.Context, db *sql.DB, userID uuid.UUID, deviceID, platform, appVersion, ip, countryCode, countryName, city, timezone string) {
	_, _ = db.ExecContext(ctx, `
		INSERT INTO user_login_events (user_id, device_id, platform, app_version, ip_address, country_code, country_name, city, timezone)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`, userID, deviceID, platform, appVersion, ip, countryCode, countryName, city, timezone)

	_, _ = db.ExecContext(ctx, `
		UPDATE users SET last_login_at = now(), updated_at = now() WHERE id = $1
	`, userID)
}
