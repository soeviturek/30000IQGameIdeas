class_name ArenaBounds
extends RefCounted
# 竞技场边界常量：镜头 limit / 刷怪范围 / 地火落点 / 边界雾气 统一读这里，
# 以后再改地图大小只改这一处。地图 = 2*HALF_WIDTH × 2*HALF_HEIGHT，居中于世界原点。

const HALF_WIDTH := 1120.0
const HALF_HEIGHT := 600.0
const MARGIN := 60.0        # 生成点/落点离墙留白，避免贴墙生成
