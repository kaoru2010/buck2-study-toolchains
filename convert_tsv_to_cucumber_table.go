package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
)

// ネガティブプレフィックス用の定数
// '~' のままでもよいですが、変更に強いようにハードコーディングを避けています。
const NegPrefix = "~"

// convertTsvToCucumberTable は、PICTのTSV出力をCucumber形式に変換し、
// ネガティブプレフィックスが含まれる場合のみ IS_ERROR カラムを付与します。
// また、ヘッダーとデータの間にダッシュ行を出力しません。
func convertTsvToCucumberTable(inputFilePath, outputFilePath string) error {
	// 入力ファイルを開く
	inFile, err := os.Open(inputFilePath)
	if err != nil {
		return fmt.Errorf("入力ファイルを開けません: %v", err)
	}
	defer inFile.Close()

	// 入力をすべて読み込み（空行はスキップ）
	var lines []string
	scanner := bufio.NewScanner(inFile)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			lines = append(lines, line)
		}
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("ファイル読み込みエラー: %v", err)
	}
	if len(lines) == 0 {
		return fmt.Errorf("入力ファイルにデータがありません")
	}

	// TSV(タブ区切り)を二次元スライス化
	var data [][]string
	for _, l := range lines {
		row := strings.Split(l, "\t")
		data = append(data, row)
	}

	// 先頭行がヘッダ、それ以降がデータ行
	// ネガティブプレフィックスが1件でも見つかったかどうかを判定
	foundNegPrefix := false

	// 各行について、ネガティブプレフィックスが含まれていれば除去し、フラグを立てる
	// ここでは、行単位で「その行がエラーかどうか」を保持するために、bool配列を用いる
	errorOnRow := make([]bool, len(data)) // 0番目はヘッダ行なので使わないが、行数分用意
	for rowIndex := 1; rowIndex < len(data); rowIndex++ {
		row := data[rowIndex]
		for colIndex, cell := range row {
			if strings.HasPrefix(cell, NegPrefix) {
				// ネガティブプレフィックスを取り除いた値に更新
				row[colIndex] = strings.TrimPrefix(cell, NegPrefix)
				// 行がエラーであることを記録
				errorOnRow[rowIndex] = true
				foundNegPrefix = true
			}
		}
	}

	// ネガティブプレフィックスが1つでもあれば、IS_ERRORカラムを追加する
	// ヘッダ行(data[0]) の末尾に "IS_ERROR" を追記
	if foundNegPrefix {
		data[0] = append(data[0], "IS_ERROR")
		// データ行に TRUE / FALSE を追記
		for rowIndex := 1; rowIndex < len(data); rowIndex++ {
			if errorOnRow[rowIndex] {
				data[rowIndex] = append(data[rowIndex], "TRUE")
			} else {
				data[rowIndex] = append(data[rowIndex], "FALSE")
			}
		}
	}

	// 各列の最大幅を算出
	numCols := len(data[0])
	colWidths := make([]int, numCols)
	for _, row := range data {
		for i, cell := range row {
			length := len(cell)
			if length > colWidths[i] {
				colWidths[i] = length
			}
		}
	}

	// Cucumberテーブルの行を作成するヘルパー
	makeRowLine := func(row []string) string {
		parts := make([]string, len(row))
		for i, cell := range row {
			pad := colWidths[i] - len(cell)
			parts[i] = cell + strings.Repeat(" ", pad)
		}
		return "| " + strings.Join(parts, " | ") + " |"
	}

	// 出力ファイルが指定されていればファイルへ、なければ標準出力へ
	var outFile *os.File
	if outputFilePath != "" {
		outFile, err = os.Create(outputFilePath)
		if err != nil {
			return fmt.Errorf("出力ファイルを作成できません: %v", err)
		}
		defer outFile.Close()
	}

	// ライターヘルパー
	writeLine := func(line string) {
		if outFile != nil {
			fmt.Fprintln(outFile, line)
		} else {
			fmt.Println(line)
		}
	}

	// 出力処理
	// 1行目はヘッダ
	writeLine(makeRowLine(data[0]))
	// ダッシュの区切り行は出力しないのでスキップ

	// データ行
	for _, row := range data[1:] {
		writeLine(makeRowLine(row))
	}

	return nil
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "使い方: %s <入力ファイル> [出力ファイル]\n", os.Args[0])
		os.Exit(1)
	}

	inputFilePath := os.Args[1]
	outputFilePath := ""
	if len(os.Args) >= 3 {
		outputFilePath = os.Args[2]
	}

	if err := convertTsvToCucumberTable(inputFilePath, outputFilePath); err != nil {
		log.Fatalf("エラー: %v\n", err)
	}
}
