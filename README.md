# 降水強度タイル生成パイプライン

GFS（Global Forecast System）の降水強度データ（PRATE）をWebマッピング用のタイル形式に変換するパイプラインです。GRIB2形式の気象データをGeoTIFFを経由してTerrainRGBエンコードされたPMTilesに変換します。

## 概要

このパイプラインは、NOAA（アメリカ海洋大気庁）のGFS気象予報データから降水強度情報を抽出し、Webマップで効率的に表示できる形式に変換します。

### データフロー

```
GRIB2 → GeoTIFF → Web Mercator → TerrainRGB → ラスタータイル → MBTiles → PMTiles
  ↓         ↓           ↓            ↓            ↓           ↓         ↓
grib2/    tif/    tif_3857/  tif_3857_terrainrgb/  (一時)   (一時)  terrainrgb/
```

## 必要な環境

- Docker（地理空間データ処理用）
- Node.js（mbtilesとpmtilesツール用）

### 必要なNode.jsパッケージ

```bash
npm install -g mb-util pmtiles
```

## 使用方法

### 基本的な実行方法

```bash
# 今日のデータで全パイプラインを実行（0-23時間先の予報）
./run_pipeline.sh

# 特定の日付で実行
./run_pipeline.sh 20251115

# 特定の日付と時間範囲で実行
./run_pipeline.sh 20251115 0 12

# 個別ステップの実行
./run_pipeline.sh 20251115 0 12 fetch     # データ取得のみ
./run_pipeline.sh 20251115 0 12 geotiff   # GeoTIFF作成のみ
./run_pipeline.sh 20251115 0 12 terrainrgb # TerrainRGBタイル作成のみ
```

### パラメータ説明

- `DATE`: 処理対象日付（YYYYMMDD形式、省略時は今日）
- `START_HOUR`: 開始予報時間（0-384、省略時は0）
- `END_HOUR`: 終了予報時間（0-384、省略時は23）
- `STEPS`: 実行ステップ（`all`|`fetch`|`geotiff`|`terrainrgb`、省略時は`all`）

### ヘルプの表示

```bash
./run_pipeline.sh --help
```

## パイプライン詳細

### ステップ1: データ取得（01_fetch_prate.sh）

- NOAA GFSデータからPRATE（降水強度）を抽出
- データソース: `s3://noaa-gfs-bdp-pds/gfs.YYYYMMDD/00/atmos/`
- 出力: `grib2/prate_YYYYMMDD_HHH.grib2`
- 単位: kg/m²/s（キログラム毎平方メートル毎秒）

### ステップ2: GeoTIFF変換（02_create_geotiff.sh）

- GRIB2ファイルをGeoTIFF形式に変換
- 単位変換: kg/m²/s → mm/h（ミリメートル毎時）
- 変換係数: 3600倍
- 出力: `tif/prate_YYYYMMDD_HHH.tif`

### ステップ3: TerrainRGBタイル作成（03_create_prate_terrainRGB.sh）

1. **座標系変換**: EPSG:4326 → EPSG:3857（Web Mercator）
2. **TerrainRGBエンコード**: 降水強度値をRGBチャンネルに格納
3. **タイル生成**: ズームレベル0-4のラスタータイル作成
4. **MBTiles作成**: タイルをMBTiles形式にパッケージ
5. **PMTiles変換**: MBTilesをPMTiles形式に変換

## 技術仕様

### 使用するDockerイメージ

- `28mm/wgrib2`: GRIB2データ処理
- `ghcr.io/osgeo/gdal:alpine-normal-latest`: 地理空間データ変換
- `helmi03/rio-rgbify`: TerrainRGBエンコード

### TerrainRGBエンコード設定

- ベース値: `-10000`（負の値やゼロ値の処理用）
- 間隔: `0.1`（0.1mm/h精度）
- 24ビットRGBチャンネルで降水強度を表現

### 座標系と範囲

- 入力座標系: EPSG:4326（WGS84）
- 出力座標系: EPSG:3857（Web Mercator）
- 処理範囲: `-180 -85.051129 180 85.051129`（Web Mercator限界）

## ファイル構成

```
create-precipitation-tiles/
├── run_pipeline.sh              # メインパイプライン実行スクリプト
├── 01_fetch_prate.sh           # データ取得スクリプト
├── 02_create_geotiff.sh        # GeoTIFF変換スクリプト
├── 03_create_prate_terrainRGB.sh # TerrainRGBタイル作成スクリプト
├── grib2/                      # GRIB2ファイル（~50MB/ファイル）
├── tif/                        # GeoTIFFファイル（~200MB/ファイル）
├── tif_3857/                   # 再投影済みTIFFファイル
├── tif_3857_terrainrgb/        # TerrainRGB TIFFファイル
└── terrainrgb/                 # 最終PMTilesファイル（~5MB/ファイル）
```

## データソース

- **NOAA GFS**: アメリカ海洋大気庁の全球気象予報システム
- **更新頻度**: 6時間毎（00, 06, 12, 18 UTC）
- **予報範囲**: 0-384時間先（16日間）
- **空間解像度**: 0.25度間隔

## ライセンス

このプロジェクトのコードはMITライセンスです。