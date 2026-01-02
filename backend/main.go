package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
	"github.com/lib/pq"
	_ "github.com/lib/pq"
)

var db *sql.DB

// --- 構造体定義 ---

type DashboardStats struct {
	TotalScore   int            `json:"total_score"`
	RecentGames  []GameSummary  `json:"recent_games"`
	ChartData    []ChartPoint   `json:"chart_data"`
}

type GameSummary struct {
	ID           int       `json:"id"`
	PlaceName    string    `json:"place_name"`
	PlayedAt     time.Time `json:"played_at"`
	Score        int       `json:"score"`
}

type ChartPoint struct {
	Date            string `json:"date"`
	DailyScore      int    `json:"daily_score"`
	CumulativeScore int    `json:"cumulative_score"`
}

// アクティビティ（共通）
type Activity struct {
	ID           int       `json:"id"`
	UserID       string    `json:"user_id"`
	Category     string    `json:"category"`
	PlayedAt     time.Time `json:"played_at"`
	PlaceName    string    `json:"place_name"`
	SummaryText  string    `json:"summary_text"`
	PrimaryScore int       `json:"primary_score"`
	ImageURLs    []string  `json:"image_urls"`
	
	// 各種詳細データ
	Mahjong      *MahjongData `json:"mahjong_data,omitempty"`
	Golf         *GolfData    `json:"golf_data,omitempty"` // ★追加
}

// 麻雀用データ構造
type MahjongData struct {
	PlayerCount int      `json:"player_count"`
	PlayerNames []string `json:"player_names"`
	HasChip     int      `json:"has_chip"`
	Chips       []int    `json:"chips"`
	Rounds   []MahjongRound   `json:"rounds"`
	Yakumans []MahjongYakuman `json:"yakumans"`
}
type MahjongRound struct {
	RoundNumber int   `json:"round_number"`
	Scores      []int `json:"scores"`
}
type MahjongYakuman struct {
	RoundNumber int    `json:"round_number"`
	PlayerIndex int    `json:"player_index"`
	YakumanName string `json:"yakuman_name"`
	ImagePath   string `json:"image_path"`
}

// ★ゴルフ用データ構造（追加）
type GolfData struct {
	MemberNames []string    `json:"member_names"` // プレイヤー名リスト
	Scores      [][]int     `json:"scores"`       // [ホールidx][プレイヤーidx]
	MyStats     []GolfStats `json:"my_stats"`     // 自分の詳細スタッツ
	Weather     string      `json:"weather"`
	Wind        string      `json:"wind"`
}
type GolfStats struct {
	Putt   int `json:"putt"`
	OB     int `json:"ob"`
	Bunker int `json:"bunker"`
}

func main() {
	connStr := fmt.Sprintf("postgres://%s:%s@%s:5432/%s?sslmode=disable",
		getEnv("DB_USER", "pgsql_user"),
		getEnv("DB_PASSWORD", "pgsql_password"),
		getEnv("DB_HOST", "db"),
		getEnv("DB_NAME", "ajito_db"),
	)

	var err error
	for i := 0; i < 5; i++ {
		db, err = sql.Open("postgres", connStr)
		if err == nil && db.Ping() == nil {
			fmt.Println("🚀 PostgreSQLに接続成功！")
			break
		}
		time.Sleep(2 * time.Second)
	}
	if err != nil { log.Fatal(err) }
	defer db.Close()

	e := echo.New()
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())
	e.Use(middleware.CORSWithConfig(middleware.CORSConfig{
		AllowOrigins: []string{"*"},
		AllowMethods: []string{http.MethodGet, http.MethodPut, http.MethodPost, http.MethodDelete},
	}))

	os.MkdirAll("uploads", os.ModePerm)
	e.Static("/uploads", "uploads")

	e.POST("/api/upload", uploadImage)
	e.GET("/api/dashboard", getDashboard)
	e.POST("/api/activities", createActivity)
	e.GET("/api/activities", getActivities)
	e.GET("/api/activities/:id", getActivity)

	fmt.Println("Server running on :8080")
	e.Logger.Fatal(e.Start(":8080"))
}

// --- ハンドラー ---

func uploadImage(c echo.Context) error {
	file, err := c.FormFile("image")
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "No file uploaded"})
	}
	src, err := file.Open()
	if err != nil { return err }
	defer src.Close()

	filename := fmt.Sprintf("%d_%s", time.Now().Unix(), file.Filename)
	savePath := filepath.Join("uploads", filename)
	dst, err := os.Create(savePath)
	if err != nil { return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to save file"}) }
	defer dst.Close()
	if _, err = io.Copy(dst, src); err != nil { return err }

	fileURL := "/uploads/" + filename
	return c.JSON(http.StatusOK, map[string]string{"url": fileURL})
}

func getDashboard(c echo.Context) error {
	stats := DashboardStats{}
	// 麻雀データのみ集計
	rows, err := db.Query(`SELECT id, place_name, played_at, primary_score FROM activities WHERE category = 'mahjong' ORDER BY played_at DESC LIMIT 5`)
	if err != nil { return c.JSON(500, err.Error()) }
	defer rows.Close()
	for rows.Next() {
		var g GameSummary
		if err := rows.Scan(&g.ID, &g.PlaceName, &g.PlayedAt, &g.Score); err == nil {
			stats.RecentGames = append(stats.RecentGames, g)
		}
	}

	currentYear := time.Now().Year()
	startOfYear := time.Date(currentYear, 1, 1, 0, 0, 0, 0, time.Local)
	rows2, err := db.Query(`SELECT played_at, primary_score FROM activities WHERE category = 'mahjong' AND played_at >= $1 ORDER BY played_at ASC`, startOfYear)
	if err != nil { return c.JSON(500, err.Error()) }
	defer rows2.Close()
	cumulative := 0
	for rows2.Next() {
		var t time.Time
		var score int
		rows2.Scan(&t, &score)
		cumulative += score
		stats.ChartData = append(stats.ChartData, ChartPoint{Date: t.Format("01/02"), DailyScore: score, CumulativeScore: cumulative})
	}
	stats.TotalScore = cumulative
	return c.JSON(http.StatusOK, stats)
}

func createActivity(c echo.Context) error {
	a := new(Activity)
	if err := c.Bind(a); err != nil { return c.JSON(400, err.Error()) }
	a.UserID = "user_001"
	if a.PlayedAt.IsZero() { a.PlayedAt = time.Now() }

	tx, err := db.Begin()
	if err != nil { return c.JSON(500, err.Error()) }
	defer tx.Rollback()

	// JSONデータの準備
	var mahjongDataArg interface{} = nil
	if a.Category == "mahjong" && a.Mahjong != nil {
		mahjongBytes, _ := json.Marshal(a.Mahjong)
		mahjongDataArg = mahjongBytes // JSONBとして保存するため[]byteまたはstring
	}
	
	// ★ゴルフデータの準備
	var golfDataArg interface{} = nil
	if a.Category == "golf" && a.Golf != nil {
		golfBytes, _ := json.Marshal(a.Golf)
		golfDataArg = golfBytes
	}

	var activityID int
	// ★SQL修正: golf_data カラムを追加
	err = tx.QueryRow(`
		INSERT INTO activities (user_id, category, played_at, place_name, summary_text, primary_score, image_urls, mahjong_data, golf_data)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING id`,
		a.UserID, a.Category, a.PlayedAt, a.PlaceName, a.SummaryText, a.PrimaryScore, pq.Array(a.ImageURLs), mahjongDataArg, golfDataArg,
	).Scan(&activityID)
	
	if err != nil { return c.JSON(500, "Insert error: "+err.Error()) }
	a.ID = activityID

	// 麻雀の詳細テーブル保存（既存機能維持）
	if a.Category == "mahjong" && a.Mahjong != nil {
		if err := insertMahjongData(tx, activityID, a.Mahjong); err != nil {
			return c.JSON(500, "Mahjong detail error: "+err.Error())
		}
	}

	if err := tx.Commit(); err != nil { return c.JSON(500, err.Error()) }
	return c.JSON(http.StatusCreated, a)
}

func getActivities(c echo.Context) error {
	userID := "user_001"
	category := c.QueryParam("category")
	query := `SELECT id, user_id, category, played_at, place_name, summary_text, primary_score, image_urls, mahjong_data, golf_data FROM activities WHERE user_id = $1`
	args := []interface{}{userID}
	if category != "" {
		query += " AND category = $2"
		args = append(args, category)
	}
	query += " ORDER BY played_at DESC LIMIT 20"

	rows, err := db.Query(query, args...)
	if err != nil { return c.JSON(500, err.Error()) }
	defer rows.Close()

	var list []Activity
	for rows.Next() {
		var a Activity
		var uid sql.NullString
		var mjData []byte
		var golfData []byte // ★ゴルフデータ取得用

		if err := rows.Scan(&a.ID, &uid, &a.Category, &a.PlayedAt, &a.PlaceName, &a.SummaryText, &a.PrimaryScore, pq.Array(&a.ImageURLs), &mjData, &golfData); err != nil {
			return c.JSON(500, err.Error())
		}
		if uid.Valid { a.UserID = uid.String }
		if mjData != nil { json.Unmarshal(mjData, &a.Mahjong) }
		if golfData != nil { json.Unmarshal(golfData, &a.Golf) } // ★ゴルフデータ展開

		list = append(list, a)
	}
	return c.JSON(http.StatusOK, list)
}

// --- Helper ---
func insertMahjongData(tx *sql.Tx, activityID int, m *MahjongData) error {
	_, err := tx.Exec(`INSERT INTO mahjong_sessions (activity_id, player_count, player1_name, player2_name, player3_name, player4_name, has_chip, chip_p1, chip_p2, chip_p3, chip_p4) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`, activityID, m.PlayerCount, getS(m.PlayerNames, 0), getS(m.PlayerNames, 1), getS(m.PlayerNames, 2), getS(m.PlayerNames, 3), m.HasChip, getI(m.Chips, 0), getI(m.Chips, 1), getI(m.Chips, 2), getI(m.Chips, 3))
	if err != nil { return err }
	stmt, _ := tx.Prepare(`INSERT INTO mahjong_rounds (activity_id, round_number, score_p1, score_p2, score_p3, score_p4) VALUES ($1, $2, $3, $4, $5, $6)`)
	defer stmt.Close()
	for _, r := range m.Rounds {
		if _, err := stmt.Exec(activityID, r.RoundNumber, getI(r.Scores, 0), getI(r.Scores, 1), getI(r.Scores, 2), getI(r.Scores, 3)); err != nil { return err }
	}
	if len(m.Yakumans) > 0 {
		stmtY, _ := tx.Prepare(`INSERT INTO mahjong_yakumans (activity_id, round_number, player_index, yakuman_name, image_path) VALUES ($1, $2, $3, $4, $5)`)
		defer stmtY.Close()
		for _, y := range m.Yakumans {
			if _, err := stmtY.Exec(activityID, y.RoundNumber, y.PlayerIndex, y.YakumanName, y.ImagePath); err != nil { return err }
		}
	}
	return nil
}
func getS(arr []string, i int) string { if i < len(arr) { return arr[i] }; return "" }
func getI(arr []int, i int) int { if i < len(arr) { return arr[i] }; return 0 }
func getEnv(key, def string) string { if v := os.Getenv(key); v != "" { return v }; return def }

// ID指定で1件取得するハンドラ
func getActivity(c echo.Context) error {
    id := c.Param("id")
    
    // DBから取得
    var a Activity
    // golf_data (JSONB) もしっかり取得します
    // ※ activitiesテーブルのカラム構成に合わせて調整してください
    query := `
        SELECT id, category, played_at, place_name, primary_score, golf_data 
        FROM activities 
        WHERE id = $1`
    
    // JSONBをスキャンするための一時変数
    var golfDataRaw []byte

    err := db.QueryRow(query, id).Scan(
        &a.ID, &a.Category, &a.PlayedAt, &a.PlaceName, &a.PrimaryScore, &golfDataRaw,
    )
    if err != nil {
        return c.JSON(http.StatusNotFound, map[string]string{"message": "Not found"})
    }

    // JSONBを構造体にパース (Categoryがgolfの場合)
    if a.Category == "golf" && len(golfDataRaw) > 0 {
        json.Unmarshal(golfDataRaw, &a.Golf)
    }

    return c.JSON(http.StatusOK, a)
}