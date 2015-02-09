package untypedTest;
/**
 * 
 * 
 * @auther sipo
 */
class UntypedTest
{
	/** コンストラクタ */
	public function new() 
	{
        trace("c");
        var a = untyped __new__(flash.display.Sprite);
        trace("b");
        trace(a);
	}
}
