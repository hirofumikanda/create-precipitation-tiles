#!/bin/bash

# 降水強度データ処理パイプライン実行スクリプト
# 引数で処理対象とする時間の範囲を指定可能

# 引数の説明を表示する関数
show_usage() {
    echo "Usage: $0 [DATE] [START_HOUR] [END_HOUR] [STEPS]"
    echo "  DATE: 日付（YYYYMMDD形式、デフォルト: 今日）"
    echo "  START_HOUR: 開始時間（0-384、デフォルト: 0）"
    echo "  END_HOUR: 終了時間（0-384、デフォルト: 23）"
    echo "  STEPS: 実行ステップ（all|fetch|geotiff|terrainrgb、デフォルト: all）"
    echo ""
    echo "実行例:"
    echo "  $0  # 今日の0-23時間先まで全ステップ実行"
    echo "  $0 20251101  # 2025年11月1日の0-23時間先まで全ステップ実行"
    echo "  $0 20251101 0 12  # 2025年11月1日の0-12時間先まで全ステップ実行"
    echo "  $0 20251101 0 12 fetch  # 2025年11月1日の0-12時間先のデータ取得のみ"
    echo "  $0 20251101 0 12 geotiff  # 既存データからGeoTiff作成のみ"
}

# ヘルプオプションの処理
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# 引数の設定
DATE=${1:-$(date +%Y%m%d)}
START_HOUR=${2:-0}
END_HOUR=${3:-23}
STEPS=${4:-all}

# 引数の検証
if ! [[ "$START_HOUR" =~ ^[0-9]+$ ]] || ! [[ "$END_HOUR" =~ ^[0-9]+$ ]]; then
    echo "エラー: START_HOURとEND_HOURは数値で指定してください"
    show_usage
    exit 1
fi

if [[ $START_HOUR -gt $END_HOUR ]]; then
    echo "エラー: START_HOUR ($START_HOUR) はEND_HOUR ($END_HOUR) より小さくする必要があります"
    show_usage
    exit 1
fi

if [[ $START_HOUR -lt 0 || $END_HOUR -gt 384 ]]; then
    echo "エラー: 時間は0-384の範囲で指定してください"
    show_usage
    exit 1
fi

if [[ ! "$STEPS" =~ ^(all|fetch|geotiff|terrainrgb)$ ]]; then
    echo "エラー: STEPSは all|fetch|geotiff|terrainrgb のいずれかを指定してください"
    show_usage
    exit 1
fi

echo "========================================"
echo "降水強度データ処理パイプライン開始"
echo "日付: $DATE"
echo "時間範囲: $START_HOUR - $END_HOUR"
echo "実行ステップ: $STEPS"
echo "========================================"

# 各ステップの実行
run_step() {
    local step_name="$1"
    local script_name="$2"
    
    echo ""
    echo "========== $step_name 開始 =========="
    if [[ "$STEPS" == "all" || "$STEPS" == "$step_name" ]]; then
        if [[ -f "$script_name" ]]; then
            bash "$script_name" "$DATE" "$START_HOUR" "$END_HOUR"
            if [[ $? -eq 0 ]]; then
                echo "✓ $step_name 完了"
            else
                echo "✗ $step_name でエラーが発生しました"
                exit 1
            fi
        else
            echo "✗ スクリプト $script_name が見つかりません"
            exit 1
        fi
    else
        echo "スキップ: $step_name"
    fi
    echo "========== $step_name 終了 =========="
}

# ステップ実行
if [[ "$STEPS" == "all" || "$STEPS" == "fetch" ]]; then
    run_step "データ取得" "01_fetch_prate.sh"
fi

if [[ "$STEPS" == "all" || "$STEPS" == "geotiff" ]]; then
    run_step "GeoTiff作成" "02_create_geotiff.sh"
fi

if [[ "$STEPS" == "all" || "$STEPS" == "terrainrgb" ]]; then
    run_step "TerrainRGB作成" "03_create_prate_terrainRGB.sh"
fi

echo ""
echo "========================================"
echo "降水強度データ処理パイプライン完了"
echo "========================================"