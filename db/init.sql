-- 既存テーブルのクリーンアップ
DROP TABLE IF EXISTS yakumans;
DROP TABLE IF EXISTS rounds;
DROP TABLE IF EXISTS mahjong_sessions; -- 名前を変えます
DROP TABLE IF EXISTS activities;       -- ★新規追加
DROP TABLE IF EXISTS users;            -- ★新規追加

-- 1. ユーザーテーブル (SNSの基本)
CREATE TABLE users (
    user_id TEXT PRIMARY KEY,
    user_name TEXT NOT NULL,
    user_info TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. アクティビティテーブル (SNSのタイムライン用・全ての競技の親)
CREATE TABLE activities (
    id SERIAL PRIMARY KEY,
    user_id TEXT REFERENCES users(username),
    category TEXT NOT NULL,       -- 'mahjong', 'golf', 'pachinko' など
    played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    place_name TEXT NOT NULL,              -- 場所（雀荘名、ゴルフ場名）
    summary_text TEXT,            -- 「倍満あがった！」などのひとこと
    primary_score INTEGER,        -- 順位やスコアなど、一覧表示用の代表数値
    image_urls TEXT[]             -- 写真URLの配列
);

-- 3. 麻雀：対局セッション (activitiesテーブルの子)
CREATE TABLE mahjong_sessions (
    activity_id INTEGER PRIMARY KEY REFERENCES activities(id) ON DELETE CASCADE,
    -- 以下、麻雀固有データ
    player_count INTEGER,
    player1_name TEXT NOT NULL,
    player2_name TEXT,
    player3_name TEXT,
    player4_name TEXT,
    has_chip INTEGER DEFAULT 0,
    chip_p1 INTEGER,
    chip_p2 INTEGER,
    chip_p3 INTEGER,
    chip_p4 INTEGER
);

-- 4. 麻雀：各局スコア (mahjong_sessionsの子)
CREATE TABLE mahjong_rounds (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER REFERENCES mahjong_sessions(activity_id) ON DELETE CASCADE,
    round_number INTEGER,
    score_p1 INTEGER NOT NULL,
    score_p2 INTEGER,
    score_p3 INTEGER,
    score_p4 INTEGER
);

-- 5. 麻雀：役満 (mahjong_sessionsの子)
CREATE TABLE mahjong_yakumans (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER REFERENCES mahjong_sessions(activity_id) ON DELETE CASCADE,
    round_number INTEGER,
    player_index INTEGER,
    yakuman_name TEXT,
    image_path TEXT
);

-- ★今後ゴルフを追加する場合のイメージ（今は実行しなくてOK）
-- CREATE TABLE golf_scores (
--    activity_id INTEGER PRIMARY KEY REFERENCES activities(id),
--    weather TEXT,
--    total_strokes INTEGER
-- );