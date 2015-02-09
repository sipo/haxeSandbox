package wave;
/**
 * 
 * 
 * @auther sipo
 */
import flash.filters.DisplacementMapFilterMode;
import flash.filters.DisplacementMapFilter;
import flash.display.BlendMode;
import flash.filters.ColorMatrixFilter;
import flash.filters.ConvolutionFilter;
import flash.filters.BitmapFilter;
import wave.Wave.WaveSource;
import flash.geom.Rectangle;
import flash.geom.Point;
import flash.events.Event;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.Lib;
import flash.display.Sprite;
class Wave
{
	/* 表示レイヤー  */
	private var layer:Sprite;
	
	/* 最終出力 */
	private var resultBitmap:Bitmap;
	private var result:BitmapData;
	
	/* 元データ */
	private var original:BitmapData;
	private var shadowOriginal:BitmapData;
	/* 波を表現するビットマップ（複数組み合わせ式） */
	private var waveSourceList:Array<WaveSource> = [];
	private var margeWave:BitmapData;
	/* 角度マップ  */
//	private var differential:BitmapData;
//	private var differentialFilter:ConvolutionFilter;
	/* ハイライト */
	private var highLight:BitmapData;
	private var highLightFilter:ColorMatrixFilter;
	/* 影 */
	private var shadow:BitmapData;
	
	/** サイズ */
	public static var WIDTH:Int = 400;
	public static var HEIGHT:Int = 400;
	/* 共通データ */
	private var rect:Rectangle = new Rectangle(0, 0, WIDTH, HEIGHT);
	private var point:Point = new Point(0, 0);
	private var baseBmd:BitmapData = new BitmapData(WIDTH, HEIGHT, false, 0x000000);
	private var halfAlpha:BitmapData = new BitmapData(WIDTH, HEIGHT, true, 0x88888888);
	
	/** コンストラクタ */
	public function new() 
	{
		layer = flash.Lib.current;
//		original = new BitmapData(WIDTH, HEIGHT, false, 0x4ea4b5);
		original = new WaveOriginal(0, 0);
		shadowOriginal = new WaveShadow(0, 0);
		// 表示用
		result = baseBmd.clone();
		resultBitmap = new Bitmap(result);
		layer.addChild(resultBitmap);
		// 準備
		waveSourceList.push(new WaveSource(new Point(0, 0.5)));
		waveSourceList.push(new WaveSource(new Point(0, -1)));
		margeWave = baseBmd.clone();
//		differential = baseBmd.clone();
		highLight = baseBmd.clone();
		shadow = halfAlpha.clone();
		// 角度抽出
		var matrix:Array<Float> = 
			[0, -1, 0,
			 0, 1, 0,
			 0, 1, 0
			];
//		differentialFilter = new ConvolutionFilter(3, 3, matrix, 1, 0, true);
		// ハイライト変換
		highLightFilter = new ColorMatrixFilter(createContrastMatrix(190, 230));
		// イベントの登録
		layer.addEventListener(Event.ENTER_FRAME, frame);
		frame(null);
	}
	
	/* フレーム動作 */
	private function frame(event:Event):Void
	{
		// 波の元データを生成
		for(i in 0...waveSourceList.length)
		{
			var waveSource:WaveSource = waveSourceList[i];
			// 移動
			waveSource.update();
			// マージ
			if (i == 0) margeWave.copyPixels(waveSource.bmd, waveSource.sourceRect, point);
			else margeWave.copyPixels(waveSource.bmd, waveSource.sourceRect, point, halfAlpha, point, true);
		}
//		result.copyPixels(margeWave, rect, point);
		
		// 波のハイライトのため、波マップを横方向に変換（この処理無くてもそれっぽく見えるかも）
//		differential.applyFilter(margeWave, rect, point, differentialFilter);
		// result.copyPixels(differential, rect, point);
		
		// コントラストを上げて波のハイライトにする
		highLight.applyFilter(margeWave, rect, point, highLightFilter);
//		result.copyPixels(highLight, rect, point);
		
		result.copyPixels(original, rect, point);
		shadow.applyFilter(shadowOriginal, rect, point, new DisplacementMapFilter(margeWave, point, 1, 2, 20, 40, DisplacementMapFilterMode.CLAMP));
		
		result.draw(highLight, null, null, BlendMode.ADD);	// 色的にADDである意味は薄いかも
		result.copyPixels(shadow, rect, point, null, null, true);
	}
	
	/* コントラスト用のマトリックスを作る */
	private function createContrastMatrix(left:Float, right:Float):Array<Float>
	{
		var scale = 255 / (right - left);
		var append = -left * scale;
		return [
			0.0, scale, 0.0, 0.0, append,
			0.0, scale, 0.0, 0.0, append,
			0.0, scale, scale, 0.0, append,
			0.0, 0.0, 0.0, 1.0, 0
		];
	}
}
class WaveSource
{
	/** 雲模様 */
	public var bmd:BitmapData;
	
	/** 速度 */
	public var v:Point;
	
	/* 描画位置 */
	public var sourceRect:Rectangle = new Rectangle(0, 0, Wave.WIDTH, Wave.HEIGHT);
	
	/** コンストラクタ */
	public function new(v:Point) 
	{
		this.v = v;
		var base:BitmapData = new BitmapData(Wave.WIDTH, Wave.HEIGHT);
		base.perlinNoise(80, 20, 2, Std.int(Math.random()*10000), true, true, 1 | 2, false);
		// スクロール方向に画像繰り返しを用意する。上下前提だが、他の方向が必要なら4x4にする
		/* 共通データ */
		var rect:Rectangle = new Rectangle(0, 0, Wave.WIDTH, Wave.HEIGHT);
		var point:Point = new Point(0, 0);
		bmd = new BitmapData(Wave.WIDTH * 1, Wave.HEIGHT * 2);
		bmd.copyPixels(base, rect, new Point(0, 0));
		bmd.copyPixels(base, rect, new Point(0, Wave.HEIGHT));
	}
	
	/**
	 * 移動（y方向だけ想定）
	 */
	public function update():Void
	{
		sourceRect.y += v.y;
		if (sourceRect.y < 0) sourceRect.y += Wave.HEIGHT;
		if (Wave.HEIGHT < sourceRect.y) sourceRect.y -= Wave.HEIGHT;
	}
}
@:bitmap("src/wave/waveOriginal.png")
class WaveOriginal extends flash.display.BitmapData
{
	
}

@:bitmap("src/wave/shadow.png")
class WaveShadow extends flash.display.BitmapData
{
	
}
