package mirrorTest;
/**
 * 
 * 
 * @auther sipo
 */
import jp.sipo.util.Mirror;
class MirrorTest
{
	/** コンストラクタ */
	public function new() 
	{
		var inner:Inner = new Inner("Inner0");
		var hogeSetup:HogeSetup = new HogeSetup();
		hogeSetup.context("A1", "B1", inner);
		var hoge:Hoge = new Hoge(hogeSetup);
		
		
//		var xml : flash.xml.XML = untyped __global__["flash.utils.describeType"](IHogeSetup);
//		trace(xml);
//		trace(Meta.getFields(IHogeSetup));
//		trace(Meta.getFields(HogeSetup));
		
		trace(hoge);
	}
}
private class Hoge extends HogeSetup
{
	private var hogeParam:String;
	
	/** コンストラクタ */
	public function new(hogeSetup:HogeSetup) 
	{
		super();
		var mirror:Mirror = new Mirror(Tmp.Tag, Base.Original);
		mirror.mirror(hogeSetup, this, true);
	}
	
	override public function toString():String
	{
		return '[Hoge $a $b $inner, hogeParam=$hogeParam]';
	}
}
@:rtti
private interface IHogeSetup
{
	public var a:String;
	public var b:String;
	public var inner:Inner;
}
@:rtti
private class HogeSetup implements IHogeSetup
{
	public var a:String;
	public var b:String;
	public var inner:Inner;
	
	/** コンストラクタ */
	public function new() 
	{
	}
	
	/**
	 * comment
	 */
	public function context(a:String, b:String, inner:Inner):Void
	{
		this.a = a;
		this.b = b;
		this.inner = inner;
	}
	
	public function toString():String
	{
		return '[HogeSetup $a $b $inner]';
	}
}
@:rtti
private class Inner
{
	private var message:String;
	
	/** コンストラクタ */
	public function new(message:String) 
	{
		this.message = message;
	}
	
	public function toString():String
	{
		return '[Inner $message]';
	}
}
private enum Tmp
{
	Tag;
}
// 構造型がインスタンスを持たない。インターフェース制限をあきらめるか、initialを別インスタンスにするしか無さそう
