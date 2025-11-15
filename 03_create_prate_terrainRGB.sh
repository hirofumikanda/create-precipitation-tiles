#!/bin/bash

# 引数の説明を表示する関数
show_usage() {
    echo "Usage: $0 [DATE] [START_HOUR] [END_HOUR]"
    echo "  DATE: 日付（YYYYMMDD形式、指定しない場合は全ファイル処理）"
    echo "  START_HOUR: 開始時間（0-384、DATEを指定した場合のみ有効）"
    echo "  END_HOUR: 終了時間（0-384、DATEを指定した場合のみ有効）"
    echo "  例: $0  # 全ファイル処理"
    echo "  例: $0 20251101  # 2025年11月1日の全時間"
    echo "  例: $0 20251101 0 12  # 2025年11月1日の0時間先から12時間先まで"
}

# ヘルプオプションの処理
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# 引数の設定
DATE=$1
START_HOUR=${2:-0}
END_HOUR=${3:-999}

if [[ -n "$DATE" ]]; then
    if [[ -n "$2" && -n "$3" ]]; then
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

        echo "Creating terrainRGB data from $DATE (hours: $START_HOUR to $END_HOUR)"
    else
        echo "Creating terrainRGB data from $DATE (all hours)"
    fi
else
    echo "Creating terrainRGB data from all TIF files in tif/ directory"
fi

# 出力ディレクトリを作成
mkdir -p tif_3857
mkdir -p tif_3857_terrainrgb
mkdir -p terrainrgb

# ファイルリストを作成
if [[ -n "$DATE" ]]; then
    if [[ -n "$2" && -n "$3" ]]; then
        # 特定の日付と時間範囲
        file_list=()
        for ((i=START_HOUR; i<=END_HOUR; i++)); do
            hour=$(printf "%03d" $i)
            file_pattern="tif/prate_${DATE}_${hour}.tif"
            if [[ -f "$file_pattern" ]]; then
                file_list+=("$file_pattern")
            fi
        done
    else
        # 特定の日付のすべてのファイル
        file_list=(tif/prate_${DATE}_*.tif)
    fi
else
    # すべてのTIFファイル
    file_list=(tif/*.tif)
fi

# ファイルを処理
for tif_file in "${file_list[@]}"; do
  if [[ -f "$tif_file" ]]; then
    # ファイル名（拡張子なし）を取得
    base_name=$(basename "$tif_file" .tif)
    echo "Processing $base_name..."

    # EPSG:3857 へ再投影（既存ファイルがある場合は削除）
    output_file="tif_3857/${base_name}_3857.tif"
    if [[ -f "$output_file" ]]; then
      rm -f "$output_file"
      echo "Removed existing file: $output_file"
    fi
    docker run --rm -u "$(id -u)":"$(id -g)" -v "$PWD":/work -w /work ghcr.io/osgeo/gdal:alpine-normal-latest \
      gdalwarp "$tif_file" "$output_file" \
        -s_srs EPSG:4326 \
        -t_srs EPSG:3857 \
        -te_srs EPSG:4326 -te -180 -85.051129 180 85.051129 \
        -r bilinear -multi -wo NUM_THREADS=ALL_CPUS

    # NoDataを外す
    docker run --rm -u "$(id -u)":"$(id -g)" -v "$PWD":/work -w /work ghcr.io/osgeo/gdal:alpine-normal-latest \
      gdal_edit.py -unsetnodata "tif_3857/${base_name}_3857.tif"

    # terrainRGB作成
    docker run --rm -u "$(id -u)":"$(id -g)" -ti -v $(pwd):/data helmi03/rio-rgbify -j 1 -b -10000 -i 0.1 \
      "tif_3857/${base_name}_3857.tif" "tif_3857_terrainrgb/${base_name}_3857_terrainrgb.tif"

    # ラスタータイル作成
    docker run --rm -u "$(id -u)":"$(id -g)" -v "$PWD":/work -w /work ghcr.io/osgeo/gdal:alpine-normal-latest \
      gdal2tiles.py "tif_3857_terrainrgb/${base_name}_3857_terrainrgb.tif" "tif_3857_terrainrgb/${base_name}_3857_terrainrgb" -z0-4 --resampling=near --xyz

    # mbtiles作成
    mb-util --image_format=png "tif_3857_terrainrgb/${base_name}_3857_terrainrgb/" "terrainrgb/${base_name}_3857_terrainrgb.mbtiles"
    rm -rf "tif_3857_terrainrgb/${base_name}_3857_terrainrgb/"

    # pmtiles変換
    pmtiles convert "terrainrgb/${base_name}_3857_terrainrgb.mbtiles" "terrainrgb/${base_name}_3857_terrainrgb.pmtiles"
    rm -f "terrainrgb/${base_name}_3857_terrainrgb.mbtiles"

    echo "Created terrainrgb/${base_name}_3857_terrainrgb.pmtiles"
  fi
done

echo "All terrainRGB tiles created successfully!"