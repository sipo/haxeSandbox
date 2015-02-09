package byteArrayTest;
/**
 * 
 * 
 * @auther sipo
 */
import flash.xml.XML;
import flash.utils.ByteArray;
class ByteArrayTest
{
	/** コンストラクタ */
	public function new() 
	{
		var original = new Hoge(TestEnum.B);
		registerClassAlias(Type.getClassName(Hoge), Hoge);
		registerClassAlias(Type.getEnumName(TestEnum), TestEnum);
		var byte:ByteArray = new ByteArray();
		byte.writeObject(original);
		
		trace(describeType(Hoge));
		trace(describeType(TestEnum));
		
		byte.position = 0;
//		registerClassAlias(Type.getEnumName(TestEnum), Dynamic);
		var testObject:Hoge = byte.readObject();
		trace(testObject);
	}
	
	private function registerClassAlias(name:String, traget:Dynamic):Void
	{
		untyped __global__[ "flash.net.registerClassAlias" ](name, traget);
	}
	private function describeType(traget:Dynamic):XML
	{
		return untyped __global__[ "flash.utils.describeType" ](traget);
	}
}
class Hoge
{
	public var testEnum:TestEnum;
	/** コンストラクタ */
	public function new(testEnum) 
	{
		this.testEnum = testEnum;
	}
}
enum TestEnum
{
	A;
	B;
}
