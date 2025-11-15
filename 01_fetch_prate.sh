#!/bin/bash

# gfs:global forecast system
# t00z:00UTC発表
# pgrb2:pressure GRIB2
# 0p25:0.25度間隔
# f000-f384:0-384時間先の予報データ

# 引数の説明を表示する関数
show_usage() {
    echo "Usage: $0 [DATE] [START_HOUR] [END_HOUR]"
    echo "  DATE: 日付（YYYYMMDD形式、デフォルト: 今日）"
    echo "  START_HOUR: 開始時間（0-384、デフォルト: 0）"
    echo "  END_HOUR: 終了時間（0-384、デフォルト: 23）"
    echo "  例: $0 20251101 0 12  # 2025年11月1日の0時間先から12時間先まで"
    echo "  例: $0 $(date +%Y%m%d) 6 18  # 今日の6時間先から18時間先まで"
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

echo "Processing GFS data for date: $DATE (hours: $START_HOUR to $END_HOUR)"

# grib2ディレクトリを作成
mkdir -p grib2

# 指定された時間範囲で繰り返し処理
for ((i=START_HOUR; i<=END_HOUR; i++)); do
  hour=$(printf "%03d" $i)
  echo "Processing f${hour}..."
  
  # GFSデータをダウンロード
#   aws s3 cp \
#     s3://noaa-gfs-bdp-pds/gfs.${DATE}/00/atmos/gfs.t00z.pgrb2.0p25.f${hour} \
#     gfs.t00z.pgrb2.0p25.f${hour} --no-sign-request

  # PRATEを取得（予報時間に応じて適切なパターンを使用）
  docker run --rm -u "$(id -u)":"$(id -g)" \
    -v "$PWD":/work -w /work 28mm/wgrib2 gfs.t00z.pgrb2.0p25.f${hour} \
    -match "PRATE:surface:${i} hour fcst:" -grib grib2/prate_${DATE}_${hour}.grib2
  
  # 一時ファイルを削除
#   rm -f gfs.t00z.pgrb2.0p25.f${hour}
  
  echo "Completed f${hour}"
done

echo "All forecast hours (f${START_HOUR}-f${END_HOUR}) processed successfully!"