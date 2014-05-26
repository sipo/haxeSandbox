package interfaceDynamicTest;
/**
 * 
 * 
 * @auther sipo
 */
class InterfaceDynamicTest
{
	/** コンストラクタ */
	public function new() 
	{
		trace(this);
		{
			var hogeDef:HogeDef = {str:"A"};
			// var hoge:Hoge = hogeDef; error
		}
		{
			var hogeDef2:HogeDef2 = {str:"A", str2:"B"};
			var hogeDef:HogeDef = hogeDef2;
			trace(Reflect.fields(hogeDef));	// [str,str2]
		}
		
	}
}
private interface Hoge
{
	public var str:String;
}
private typedef HogeDef = 
{
	public var str:String;
}

private typedef HogeDef2 = 
{
	public var str:String;
	public var str2:String;
}
