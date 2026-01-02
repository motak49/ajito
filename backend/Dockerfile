# 1. ベースイメージ（Go言語が入ったOS）を指定
FROM golang:1.25.5

# 2. コンテナ内の作業場所を決める
WORKDIR /app

# 3. 依存関係のファイルを先にコピーしてインストール
# (キャッシュを効かせてビルドを速くするため)
COPY go.mod go.sum ./
RUN go mod download

# 4. ソースコードを全てコピー
COPY . .

# 5. Goのプログラムをビルド（実行ファイルを作る）
RUN go build -o main .

# 6. ポート8080を開ける
EXPOSE 8080

# 7. コンテナ起動時に実行するコマンド
CMD ["./main"]