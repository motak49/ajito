// backend/models/user.go
package models

import "time"

type User struct {
	UserID    string    `json:"user_id" db:"user_id"`     // DBのカラム名と一致させる
	UserName  string    `json:"user_name" db:"user_name"` // username -> user_name
	UserInfo  string    `json:"user_info" db:"user_info"` // bio -> user_info
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}