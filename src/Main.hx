package ;
/**
 * 
 * 
 * @auther sipo
 */
import wave.Wave;
import flash.events.Event;
import flash.Lib;
class Main
{
	static private var my;
	
	/**
	 * 初期起動
	 */
	public static function main():Void
	{
		Lib.current.addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
	}
	
	/**
	 * ステージ追加後、少し待機して開始
	 */
	public static function addedToStageHandler(event:Event):Void
	{
		my = new Wave();
	}
}
