package main

import (
	"fmt"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	hash := "$2a$10$wNlh8gGgWk8fT9j8Xq21XOfJ7Zl.m3G3YxW9K.3sYyPeezMwqg4eq"
	password := "admin123"

	err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
	if err != nil {
		fmt.Printf("Compare failed: %v\n", err)

		// Generate a correct hash
		newHash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
		fmt.Printf("Correct hash for '%s' is: %s\n", password, string(newHash))
	} else {
		fmt.Println("Password matches hash successfully!")
	}
}
