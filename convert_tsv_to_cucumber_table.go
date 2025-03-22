package main

import (
    "bufio"
    "fmt"
    "log"
    "os"
    "strings"
)

// convertTsvToCucumberTable は、PICTの出力(タブ区切り)をCucumberのテーブル形式に変換し、
// outputFilePath が空文字であれば標準出力に、そうでなければファイルに書き出す。
func convertTsvToCucumberTable(inputFilePath, outputFilePath string) error {
    // 入力ファイルを開く
    inFile, err := os.Open(inputFilePath)
    if err != nil {
        return fmt.Errorf("入力ファイルを開けません: %v", err)
    }
    defer inFile.Close()

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

    // タブ区切りデータを二次元スライスに格納
    var data [][]string
    for _, l := range lines {
        row := strings.Split(l, "\t")
        data = append(data, row)
    }

    // 各列の最大幅を計算
    numCols := len(data[0])
    colWidths := make([]int, numCols)
    for _, row := range data {
        for i, cell := range row {
            if len(cell) > colWidths[i] {
                colWidths[i] = len(cell)
            }
        }
    }

    // Cucumberテーブル行作成用ヘルパー
    makeRowLine := func(row []string) string {
        parts := make([]string, len(row))
        for i, cell := range row {
            // 左寄せ整形
            padding := colWidths[i] - len(cell)
            parts[i] = cell + strings.Repeat(" ", padding)
        }
        return "| " + strings.Join(parts, " | ") + " |"
    }

    // ヘッダとデータ行の間に挟む区切り行
    //makeDashLine := func() string {
    //    dashes := make([]string, numCols)
    //    for i := range colWidths {
    //        dashes[i] = strings.Repeat("-", colWidths[i])
    //    }
    //    return "| " + strings.Join(dashes, " | ") + " |"
    //}

    // 出力先設定（ファイル or 標準出力）
    var outFile *os.File
    if outputFilePath != "" {
        var err error
        outFile, err = os.Create(outputFilePath)
        if err != nil {
            return fmt.Errorf("出力ファイルを作成できません: %v", err)
        }
        defer outFile.Close()
    }

    // 書き込み関数
    writeLine := func(line string) {
        if outFile != nil {
            fmt.Fprintln(outFile, line)
        } else {
            fmt.Println(line)
        }
    }

    // テーブル出力を構築
    // 1行目はヘッダ
    writeLine(makeRowLine(data[0]))
    // 区切り行
    // writeLine(makeDashLine())
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
