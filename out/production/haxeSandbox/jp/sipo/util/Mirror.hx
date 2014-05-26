package jp.sipo.util;
import Type;
import Type;
import String;
import Class;
import jp.sipo.util.Mirror.ClassConvertMap;
import haxe.Json;
import Type;
import Lambda;
import Class;
import haxe.rtti.CType;
import haxe.rtti.CType.CClass;
class Mirror 
{
	/** クラス解析のキャッシュ */
	public static var cache:Map<String, List<ClassField>>;
	
	/* --------------------------------
	 * メタデータ値名
	 * -------------------------------*/
	
	/** メタデータそのものの名前 */
	public static inline var META_NAME:String = "mirror";
	
	/* --------------------------------
	 * 呼び出し関数
	 * -------------------------------*/
	
	/** カスタムミラー時に使用する */
	public static inline var CUSTOM_METHOD_HEADER:String = "mirror_";
	/** クローン時に使用するメソッド名 */
	public static inline var CLONE_METHOD_NAME:String = "mirrorClone";
	
	/* --------------------------------
	 * 設定
	 * -------------------------------*/
	
	/* フィールド設定のベース */
	private var base:Base;
	/* 対応するメタデータのタグ名称 */
	public var tag(default, null):EnumValue;
	/* 変換時に別のクラスにする場合のリスト */
	private var classConvertMap:ClassConvertMap;
	
	/* --------------------------------
	 * その他
	 * -------------------------------*/
	
	/* コンソール表示 */
//	private var note:Note;
	
	/* ================================================================
	 * 処理
	 * ===============================================================*/
	
	
	/** コンストラクタ */
	public function new(tag:EnumValue, base:Base, ?classConvertMap:ClassConvertMap) 
	{
		if (classConvertMap == null) classConvertMap = new ClassConvertMap();
		this.tag = tag;
		this.base = base;
		this.classConvertMap = classConvertMap;
		
		if (cache == null) cache = new Map<String, List<ClassField>>();
		
//		note = new Note([Note.CommonTag.common, NoteTag.mirror]);
	}
	
	/**
	 * 変換マップの追加
	 */
	public function addConvertMap(beforeClass:Class<Dynamic>, afterClass:Class<Dynamic>):Void
	{
		classConvertMap.set(beforeClass, afterClass);
	}
	
	/**
	 * Objectのインスタンスから、ターゲットインスタンスにメンバ変数をコピーする。
	 * インスタンスの型にも対応し、深いコピーを行う
	 * 
	 * 基準targetの場合
	 * インスタンスがループしていないことが条件。フリーズするので、使用には注意
	 * originalがJSONから作られたインスタンスなどなら、大丈夫
	 * createKindは無視される
	 * 
	 * 基準originalの場合
	 * originalが型を持たないと動作しないので注意
	 */
	public function mirror(original:Dynamic, target:Dynamic, cacheDescription:Bool):Void
	{
		// 対象クラスの構造を得る
		var baseInstance:Dynamic = 
			switch (base){
				case Base.Original:original;
				case Base.Target:target;
			};
		var fields:List<ClassField> = getField(Type.getClass(baseInstance), cacheDescription);
		mirror_(original, target, fields, cacheDescription);
	}
	
	/**
	 * 構造体から変数をコピーする
	 * 浅いコピーを行う
	 */
	public static function copyFromStructure(originalStructure:Dynamic, target:Dynamic):Void
	{
		for (name in Reflect.fields(originalStructure)){
			var value:Dynamic = Reflect.getProperty(originalStructure, name);
			Reflect.setProperty(target, name, value);
		}
	}
	
	/**
	 * リストを対象にミラーする。
	 * 深いリストに対応していない
	 */
	public function listMirror(originalList:Dynamic, targetList:Dynamic, targetClass:Class<Dynamic>, cacheDescription:Bool):Void
	{
		for (i in 0...originalList.length) 
		{
			var original:Dynamic = originalList[i];
			if (original == null) throw 'ミラーするリストの内部がnullの状態に対応していません';
			var argument:InstanceCreateArgument = new InstanceCreateArgument(originalList, targetList, originalList[i], null, cacheDescription, ConvertKind.ignore, null);
			argument.className = Type.getClassName(targetClass);
//			var target:Dynamic = createSameInstanceNotList(originalList[i], Type.getClassName(targetClass), cacheDescription, false, false);
			var target:Dynamic = createSameInstanceNotList(argument);
			targetList[i] = target;
		}
	}
	
	/**
	 * フィールドを取得する。
	 * @mirrorSuperFieldが付いている場合はスーパークラスまで含んで取得する
	 */
	private function getField(clazz:Class<Dynamic>, cacheDescription:Bool):List<ClassField>
	{
		var className:String = Type.getClassName(clazz);
		if (cache.exists(className)){
			return cache.get(className);
		}
		var rtti:String = Reflect.field(clazz, "__rtti");
		if (rtti == null) throw '$clazz にrttiメタタグが指定されていません。';
		var xml = Xml.parse(rtti).firstElement();
		var infos:TypeTree = new haxe.rtti.XmlParser().processElement(xml);
		var classdef:Classdef;
		switch(infos){
			case TypeTree.TClassdecl(_classdef/*:Classdef*/):
				classdef = _classdef;
			default:
				throw 'クラス以外は未対応です';
		}
		var fields:List<ClassField> = classdef.fields;
		var ansFields:List<ClassField> = new List<ClassField>();
		// 関数などをさけて、変数のみにする
		for (field in fields) {
			switch(field.type){
				case CType.CEnum(_, _), CType.CClass(_, _), CType.CDynamic(_), CType.CAbstract(_, _):
					ansFields.push(field);
				default:continue;
			}
		}
		
		// デフォルト動作は、スーパークラスまでフィールドを取得するが、ignoreSuper:trueが指定されている場合、superクラスは捜査しない
		var mirrorMeta:MirrorMetaParameter = searchMeta(classdef.meta, tag);
		var checkSuperClass:Bool = (classdef.superClass != null && (mirrorMeta == null || !mirrorMeta.ignoreSuper));
		if (checkSuperClass){
			var superClass:Class<Dynamic> = Type.resolveClass(classdef.superClass.path);
			var superClassField = getField(superClass, cacheDescription);
			ansFields = Lambda.concat(ansFields, superClassField);
		}
		cache.set(className, ansFields);
		return ansFields;
	}
	
	/**
	 * Field情報を元に、変数をコピーする
	 */
	public function mirror_(original:Dynamic, target:Dynamic, fields:List<ClassField>, cacheDescription:Bool):Void
	{
		for (field in fields) {
			// ここで対象値を取り出しておく
			var originalValue:Dynamic = Reflect.field(original, field.name);
			
			// ミラータグが無いかチェック
			var mirrorMeta:MirrorMetaParameter = searchMeta(field.meta, tag);
			// ミラー指示を解析する
			var isIgnore:Bool = false;
			var isOptional:Bool = false;
			var isCustom:Bool = false;
			var isClone:Bool = false;
			var isConvert:Bool = false;
			
			// メタタグによる指定解析
			if (mirrorMeta != null){
				// 無効な指定がないかチェック
				for (metaFieldName in Reflect.fields(mirrorMeta)){
					switch (metaFieldName){
						case "createKind":
						case "symmetryKind":
						default :
							throw '想定しないミラー指定があります $original $field $metaFieldName';
					}
				}
				// 生成方法に関する指定
				if (mirrorMeta.createKind != null && base == Base.Original){
					var createKind:CreateKind = Type.createEnum(CreateKind, mirrorMeta.createKind);
					switch(createKind){
						case CreateKind.convert:
							isConvert = true;
						case CreateKind.custom:
							isCustom = true;
						case CreateKind.clone:
							isClone = true;
					}
				}
				// 値の対応に関する指定
				if (mirrorMeta.symmetryKind != null){
					var symmetryKind:SymmetryKind = Type.createEnum(SymmetryKind, mirrorMeta.symmetryKind);
					// TODO:Note
//					if (Type.enumEq(symmetryKind, SymmetryKind.noReady)) note.log("Mirror noReady ${original}::${field.name} -> ${target}::${field.name}");
//					if (Type.enumEq(symmetryKind, SymmetryKind.underConstruction)) note.log("Mirror underConstruction ${original}::${field.name} -> ${target}::${field.name}");
					switch(symmetryKind){
						case SymmetryKind.ignore, SymmetryKind.otherWay, SymmetryKind.noReady:
							isIgnore = true;
						case SymmetryKind.optional, SymmetryKind.underConstruction:
							isOptional = true;
					}
					// 無視の場合何もせず終了
					if (isIgnore) continue;
				}
			}
			// 対象がnullの場合の対応
			if (originalValue == null){
				if (isOptional) continue;	// 対象がnullで、optionalなら無視する
				// そうでなければnullエラー
				throw 'コピーする値がありませんでした ${original}::${field.name} -> ${target}::${field.name}';
			}
			// 精製方法に合わせて複製
			if (isCustom){	// カスタムの場合
				// カスタムメソッド名は"mirror_変数名"
				var methodName:String = CUSTOM_METHOD_HEADER + field.name;
				var argument:MirrorCustomMethodArgument = new MirrorCustomMethodArgument(original, originalValue, clone());
				// 呼び出して、コピー動作はカスタムメソッドにまかせる
				var func = Reflect.field(target, methodName);
				if (func == null) throw '${original} には ${methodName} がありません';
				Reflect.callMethod(target, func, [argument]);
				continue; // この変数はこれで終了
			}
			// クローンメソッドを持つなら、それを呼び出し
			if (isClone){
				var cloneable:IMirrorCloneable = originalValue;
//				var func = Reflect.field(originalValue, CLONE_METHOD_NAME);
//				if (func == null) throw '${originalValue} には ${CLONE_METHOD_NAME} がありません';
//				var targetValue:Dynamic = Reflect.callMethod(originalValue, func, []);
				var targetValue:Dynamic = cloneable.mirrorClone();
				Reflect.setField(target, field.name, targetValue);
				continue;
			}
			// 通常ミラー
//			var instanceType:InstanceType = InstanceType.etc;
//			if (!isPrimitive(originalValue)){
//				instanceType = cTypeToInstanceType(field.type);
//			}
			var instanceType:InstanceType = cTypeToInstanceType(field.type);
			var convertKind:ConvertKind = if (isConvert) ConvertKind.convert else ConvertKind.no;
			var argument:InstanceCreateArgument = new InstanceCreateArgument(original, target, originalValue, instanceType, cacheDescription, convertKind, field);
			var mirrorValue:Dynamic = createSameInstance(argument);
			Reflect.setField(target, field.name, mirrorValue);
			continue;
		}
		if (Std.is(target, IAfterMirrorHandler)){
			var _target:IAfterMirrorHandler = cast(target);
			_target.afterMirrorHandler(original);
		}
	}
	
	/* CTypeから、Mirrorで使用するタイプ判断に変換。ArrayとVectorが今のところ特別扱い。ネストする */
	private function cTypeToInstanceType(type:CType):InstanceType
	{
		var name:String;
		var params:List<CType>;
		// CTypeから、nameとparamを取り出す
		switch(type){
			case CType.CClass(_name, _params), CType.CAbstract(_name, _params), CType.CEnum(_name, _params):
				name = _name;
				params = _params;
			default: throw 'error${type}';
		}
		// VectorはAbstract型なので、nameでしか判別できない。ArrayはStd.isでも可能だが、とりあえずこうやってある
		if (name == "Array") return InstanceType.array(cTypeToInstanceType(params.first()));
		if (name == "haxe.ds.Vector") return InstanceType.haxeVector(cTypeToInstanceType(params.first()));
		if (name == "flash.Vector") return InstanceType.flashVector(cTypeToInstanceType(params.first()));
		return InstanceType.etc(name);
	}
	
	/* 同一インスタンスを生成する内部処理 */
	// MEMO:noConvert指定
	// MEMO:Vector->Arrayの変換未実装。これは頻出するため、個別指定で、変数タグ無しで出来るようにする。
	// MEMO:Array->Vectorの変換未実装。これは対象のインスタンスが無いとコピー出来ない問題があるので、customで対応するのがいいと思われる。インスタンスを渡すことでショートカットする機能があってもいい
	private function createSameInstance(argument:InstanceCreateArgument):Dynamic
	{
		switch(argument.instanceType){
			case InstanceType.array(innerType):
				argument.instanceType = innerType;
				return mirrorArray(this, argument);
			case InstanceType.haxeVector(innerType):
				argument.instanceType = innerType;
				return mirrorHaxeVector(this, argument);
			case InstanceType.flashVector(innerType):
				argument.instanceType = innerType;
				return mirrorFlashVector(this, argument);
			case InstanceType.etc(className):
				argument.className = className;
				return createSameInstanceNotList(argument);
		}
	}
	/* リストではないものに限ってインスタンス生成。インスタンスタイプがいらない */
	private function createSameInstanceNotList(argument:InstanceCreateArgument):Dynamic
	{
		if (isPrimitive(argument.originalValue)){	// プリミティブならそのままコピー（nullも含む）
			return argument.originalValue;
		}
		// その他の場合
		var targetClass:Class<Dynamic> = null;
		switch(argument.convert){
			case ConvertKind.convert:
				targetClass = classConvertMap.get(argument.className);
				if (targetClass == null) throw 'convert指定があるのに、変換先クラスが登録されていません。 $argument';
			case ConvertKind.no:
				targetClass = classConvertMap.get(argument.className);
				if (targetClass != null) throw '変換先クラスがあるのにconvert指定されています。 $argument';
				targetClass = Type.resolveClass(argument.className);
			case ConvertKind.ignore:
				targetClass = Type.resolveClass(argument.className);
				
		}
		var targetValue:Dynamic = Type.createEmptyInstance(targetClass);
		mirror(argument.originalValue, targetValue, argument.cacheDescription);	// 以下をmirrorAndCreateClassする
		return targetValue;
	}
	
	// 以下３つのメソッドは、挙動を共通化できそうな気もするけど、
	
	// MEMO:外部呼び出しをもっと楽にできないか
	/**
	 * Arrayのコピーに対応する
	 */
	private inline function mirrorArray(mirror:Mirror, argument:InstanceCreateArgument):Dynamic
	{
		var originalValue:Dynamic/* Array */ = argument.originalValue;
		var target = originalValue.copy();
		for (i in 0...originalValue.length) {
			argument.originalValue = originalValue[i];
			var targetInner = mirror.createSameInstance(argument);
			target[i] = targetInner;
		}
		return target;
	}
	
	/**
	 * haxe.ds.Vectorのコピーに対応する
	 * Flashのみでしか正常動作しない
	 */
	private inline function mirrorHaxeVector(mirror:Mirror, argument:InstanceCreateArgument):Dynamic
	{
		var originalValue:Dynamic/* haxe.Vector */ = argument.originalValue;
		var target:Dynamic = untyped originalValue.concat();	// Flash専用処理。他言語に対応する場合は、ここでコピーする方法を用意する
//		var target:Dynamic = Type.createInstance(Type.getClass(original), [length, true]);	// createInstanceを使う方法。これもFlash専用だし、遅くなるので上を採用。
		for (i in 0...originalValue.length) {
			argument.originalValue = originalValue[i];
			var targetInner = mirror.createSameInstance(argument);
			target[i] = targetInner;
		}
		return target;
	}
	
	/**
	 * flash.Vectorのコピーに対応する
	 * Flashのみでしか正常動作しない
	 */
	private inline function mirrorFlashVector(mirror:Mirror, argument:InstanceCreateArgument):Dynamic
	{
		var originalValue:Dynamic/* flash.Vector */ = argument.originalValue;
		var target:Dynamic = originalValue.concat();	// Flash専用処理。他言語に対応する場合は、ここでコピーする方法を用意する
		for (i in 0...originalValue.length) {
			var originalInner = originalValue[i];
			var targetInner = mirror.createSameInstance(argument);
			target[i] = targetInner;
		}
		return target;
	}
	
	/* メタデータを名前で探す */
	private function searchMeta(metaList:MetaData, tag:EnumValue):MirrorMetaParameter
	{
		var mirrorMeta:Meta = null;
		// @mirrorを見つける
		for (meta in metaList) {
			if (meta.name == META_NAME){
				mirrorMeta = meta;
				break;
			}
		}
		// 無ければ終了
		if (mirrorMeta == null) return null;
		// mirrorのパラメータを解析し、tagごとにマップを作る
		var mirrorParameterMap:Map<String, MirrorMetaParameter> = new Map();
		var mirrorParameterBlank:MirrorMetaParameter = null;
		// jsonっぽいけど、jsonじゃないので、jsonに変換してみる
		var reg:EReg = ~/([^ {}",]+):/g;
		var replace = "\"$1\":";
		for (paramString in mirrorMeta.params) {
			paramString = reg.replace(paramString, replace);
			var metaObject:MirrorMetaParameter = Json.parse(paramString);
			var metaTagString:String = metaObject.tag;
			if (metaTagString == null) mirrorParameterBlank = metaObject;
			else mirrorParameterMap.set(metaTagString, metaObject);
		}
		// タグリストの指定を検索する
		var mirrorParameter:MirrorMetaParameter = null;
		var tagString:String = Type.enumConstructor(tag);
		if (mirrorParameterMap.exists(tagString)){
			mirrorParameter = mirrorParameterMap.get(tagString);
		}
		// タグリストに一致が無くても、空のタグがあればそれを使用する
		if (mirrorParameter == null && mirrorParameterBlank != null){
			mirrorParameter = mirrorParameterBlank;
		}
		return mirrorParameter;
	}
	
	/* プリミティブかどうか判断する */
	private function isPrimitive(value:Dynamic):Bool
	{
		return if (Std.is(value, String)){
			true;
		}else{
			switch(Type.typeof(value)){
				case ValueType.TNull, ValueType.TInt, ValueType.TFloat, ValueType.TBool, ValueType.TEnum(_), ValueType.TUnknown : 
					true;
				case ValueType.TObject, ValueType.TFunction, ValueType.TClass(_) : 
					false;
			}
		}
	}
	
	/**
	 * 複製
	 */
	public function clone():Mirror
	{
		return new Mirror(tag, base, classConvertMap.clone());
	}
	
	/**
	 * キャッシュを消す
	 */
	public static function clear():Void
	{
		cache = null;
	}
	
	
	/**
	 * 文字表現
	 */
	public function toString():String
	{
		return '[Mirror tag=${tag} base=${base} classConvertMap=$classConvertMap]';
	}
}

/**
 * mirrorのクラス変換マップ
 */
class ClassConvertMap
{
	/* 格納変数 */
	private var map:Map<String, Class<Dynamic>>;
	/** コンストラクタ */
	public function new() {
		map = new Map();
	}
	
	/**
	 * 追加
	 */
	public function set(beforeClass:Class<Dynamic>, afterClass:Class<Dynamic>):Void
	{
		var beforeClassName:String = Type.getClassName(beforeClass);
		map.set(beforeClassName, afterClass);
	}
	
	/**
	 * 追加
	 */
	public function setFromString(beforeClassName:String, afterClass:Class<Dynamic>):Void
	{
		map.set(beforeClassName, afterClass);
	}
	
	/**
	 * 取得
	 */
	public function get(className:String):Class<Dynamic>
	{
		return map.get(className);
	}
	
	/**
	 * 別のClassConvertMapの内容を全て追加
	 */
	public function concatMap(target:ClassConvertMap):Void
	{
		for (beforeClassName in target.map.keys()) {
			map.set(beforeClassName, target.map.get(beforeClassName));
		}
	}
	
	/**
	 * 複製
	 */
	public function clone():ClassConvertMap
	{
		var ans:ClassConvertMap = new ClassConvertMap();
		ans.concatMap(this);
		return ans;
	}
	
	/**
	 * 文字列表現
	 */
	public function toString():String
	{
		var mapString:String = "";
		for (key in map.keys()){
			mapString += key + ":" + map.get(key) + ", ";
		}
		return '[ClassConvertMap ${mapString}]';
	}
}
/**
 * mirrorメタデータの構造定義
 */
typedef MirrorMetaParameter = 
{
	/** tag種類の指定。文字列を持ち、mirror生成時のtagListに同期する */
	@:optional var tag:String;
	/** kind種類の指定。Kindの各定数を持つ */
	@:optional var createKind:String/*CreateKind*/;
	/** kind種類の指定。Kindの各定数を持つ */
	@:optional var symmetryKind:String/*SymmetryKind*/;
	/** superクラスのミラーを無視する値名。デフォルトでfalse扱い。クラスに設定する */
	@:optional var ignoreSuper:Bool;
	
}
/**
 * Mirrorメタデータの、生成方法指定
 */
enum CreateKind
{
	/** 対象の変数は他のクラスに変換される。変換指示が無い場合はエラー */
	convert;
	/** 対象の変数は、mirror_○○で指定したメソッドで生成される */
	custom;
	/** 対象の変数は、インスタンス内部のCloneメソッドで生成される */
	clone;
}
/**
 * Mirrorメタデータの、変数に対する対応指定
 */
enum SymmetryKind
{
	/** 対象の変数は無視される */
	ignore;
	/** 対象の変数は他の方法でミラーされる。customなどは含まない。（挙動はignoreと一緒） */
	otherWay;
	/** 対象の変数は受け取る準備ができていない（挙動はignoreと一緒だが、１つでもあると警告を発生） */
	noReady;
	/** 対象の変数はnullを許容される */
	optional;
	/** 対象の変数はまだ送られてこない可能性がある（挙動はoptionalと一緒だが、１つでもあると警告を発生） */
	underConstruction;
}
typedef Meta = 
{
	var name : String;
	var params : Array<String>;
}
class InstanceCreateArgument
{
	public var fieldData:ClassField;
	public var originalValue:Dynamic;
	public var original:Dynamic;
	public var target:Dynamic;
	public var instanceType:InstanceType;
	public var cacheDescription:Bool;
	public var convert:ConvertKind;
	
	// 追加データ
	public var className:String;
	
	public function new(original:Dynamic, target:Dynamic, originalValue:Dynamic, instanceType:InstanceType, cacheDescription:Bool, convert:ConvertKind, fieldData:ClassField) 
	{
		this.original = original;
		this.target = target;
		this.originalValue = originalValue;
		this.instanceType = instanceType;
		this.cacheDescription = cacheDescription;
		this.convert = convert;
		this.fieldData = fieldData;
	}
	
	
	public function toString():String
	{
		return '[${original}.${fieldData.name} -> ${target}(${instanceType})]';
	}
}
enum ConvertKind
{
	convert;	// convert指示がある
	no;	// convert指示が無い
	ignore;	// convert指示を無視する
}
/**
 * カスタムメソッドの引数
 */
class MirrorCustomMethodArgument
{
	public var original:Dynamic;
	public var originalValue:Dynamic;
	public var mirror:Mirror;
	
	/** コンストラクタ */
	public function new(original:Dynamic, originalValue:Dynamic, mirror:Mirror) 
	{
		this.original = original;
		this.originalValue = originalValue;
		this.mirror = mirror;
	}
}
/**
 * 複製時に終了イベントを取れるクラス
 */
interface IAfterMirrorHandler
{
	function afterMirrorHandler(original:Dynamic):Void;
}
/**
 * インスタンスタイプの表現
 */
enum InstanceType
{
	haxeVector(innerType:InstanceType);
	flashVector(innerType:InstanceType);
	array(innerType:InstanceType);
	etc(className:String);
}
enum NoteTag
{
	mirror;
}
/**
 * ミラーする時の元になる側
 */
enum Base
{
	Original;
	Target;
}
/**
 * ミラー時に自動的にクローン可能なクラス
 * 
 * @author sipo
 */
interface IMirrorCloneable
{
	function mirrorClone():Dynamic;
}
/**
 * lengthを持つ型
 */
//typedef ArrayTypeDef = 
//{>ArrayAccess<Int>,
//	var length:Int;
//	function copy():Dynamic;
//}
//typedef VectorTypeDef = 
//{>ArrayAccess<Int>,
//	var length:Int;
//	function concat():Dynamic;
//}
