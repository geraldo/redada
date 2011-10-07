package {
	import flare.animate.Parallel;
	import flare.animate.Transitioner;
	import flare.data.DataSet;
	import flare.display.RectSprite;
	import flare.display.TextSprite;
	import flare.vis.Visualization;
	import flare.vis.controls.ClickControl;
	import flare.vis.controls.DragControl;
	import flare.vis.controls.HoverControl;
	import flare.vis.controls.TooltipControl;
	import flare.vis.data.Data;
	import flare.vis.data.NodeSprite;
	import flare.vis.data.EdgeSprite;
	import flare.vis.events.SelectionEvent;
	import flare.vis.events.TooltipEvent;
	import flare.vis.operator.filter.GraphDistanceFilter;
	import flare.vis.operator.layout.RadialTreeLayout;
	
	import flash.display.Sprite;
	import flash.events.*;
	import flash.geom.Rectangle;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.Timer;
	
	import mx.core.UIComponent;
	
	/**
	 * Application reading graphml file and visualizing Social Network Graph
	 */
	public class Camon extends Sprite
	{
		public var onComplete:Function;
		public var onChange:Function;
		private var vis:Visualization;
		private var labelWidth:Number;
		private var labelHeight:Number;
		private var _gdf:GraphDistanceFilter;
		private var _maxDistance:int = 3;
		private var _transitionDuration:Number = 2;
		private var _trans:Object = {};
		private var prev_node:NodeSprite = null;
		
		private var uic:UIComponent;
		private var sprite:Sprite;
		private var nodeArray:Array = new Array();
		private var red:uint = 0xdd440000;
		private var green:uint = 0xdd004400;
		private var blue:uint = 0xdd000044;
		private var yellow:uint = 0xee6800de;

		public function Camon(onComplete:Function=null,onChange:Function=null) {
	        this.onComplete = onComplete;
	        this.onChange = onChange;

			uic = new UIComponent();
			addChild(uic);
			sprite = new Sprite();
			uic.addChild(sprite);

			var gmr:GraphMLReader = new GraphMLReader(onLoaded);
			//gmr.read("mexico.xml");
			gmr.read("conexion_camon.xml");	// graphML file to read
		}
			
		private function onLoaded(data:Data):void {
			//showText("GraphML loaded "+data.length+" edges and nodes!");

			vis = new Visualization(data);
			//var w:Number = stage.stageWidth;
			//var h:Number = stage.stageHeight;
			var w:Number = 1000;
			var h:Number = 600;
			
			vis.bounds = new Rectangle(0, 0, w, h);
			//vis.continuousUpdates = true;
			var i:int = 0;
			
			vis.data.nodes.setProperty("x",w/2);
			vis.data.nodes.setProperty("y",h/2);

			var root_node:NodeSprite = vis.data.nodes[0];

			var fmt1:TextFormat = new TextFormat("Verdana",10,0x000000);
			var fmt2:TextFormat = new TextFormat("Verdana",10,0xFFFFFF);
			var fmt3:TextFormat = new TextFormat("Verdana",10,0x330000);
			
			vis.data.nodes.visit(function(ns:NodeSprite):void { 
				// draw label with color depending on type of node
				/*var fmt:TextFormat = null;
				switch (ns.data.type){
					case "ins": fmt = fmt1; break;
					case "com": fmt = fmt3; break;
					case "ind":
					case null:
					default: fmt = fmt2;
				}*/
				var fmt:TextFormat = fmt2;
				var ts:TextSprite = new TextSprite(ns.data.name,fmt);
				
				ns.addChild(ts);
				nodeArray.push({label: ns.data.name, data: ns.degree, id: ns.data.id});

				labelWidth = getTextLabelWidth(ns)+ns.degree*2-5;
				labelHeight = getTextLabelHeight(ns)+ns.degree*2-5;
			
				// draw node
				var rs:RectSprite = new RectSprite( -labelWidth/2-1,-labelHeight/2 - 1, labelWidth + 2, labelHeight );
				/*color depending of connection degree
				var blue24:uint = 0x000044;
				rs.fillColor = 0xff/0xff*ns.degree*15 << 24 | blue24;
				rs.lineColor = 0x00000000;
				//rs.fillColor = 0xff000044; 
				//rs.lineColor = 0xff000044;
				rs.lineWidth = 0;*/
				
				// draw node with color depending on type of node
				var col:uint;
				switch (ns.data.type){
					case "ins": col = red; break;
					case "ind": col = green; break;
					case "com":
					case null:
					default: col = blue;
				}
				rs.fillColor = col;
				rs.lineColor = col;
				
				ns.addChildAt(rs, 0);
				ns.size = 0;
				adjustLabel(ns,labelWidth,labelHeight);
				ns.mouseChildren = false; 
				ns.addEventListener(MouseEvent.CLICK, update);
				ns.buttonMode = true;
				
				//save node with most degrees
				if (ns.degree > root_node.degree) root_node = ns;
			});

			data.edges.visit(function(e:EdgeSprite):void {    
				//e.lineColor = 0x0000ff;    
				//e.lineAlpha = 1;
				e.lineWidth = e.data.weight;
			});

			var lay:RadialTreeLayout =  new RadialTreeLayout(50,true);
			lay.angleWidth = -2*Math.PI;
			lay.useNodeSize = false;
			
			var hc:HoverControl = new HoverControl(NodeSprite,HoverControl.MOVE_TO_FRONT,highLightOn,highlightOff);
			vis.controls.add(hc);

			var cc2:ClickControl = new ClickControl(NodeSprite,2,gotoWeb);
			vis.controls.add(cc2);
			
			_gdf = new GraphDistanceFilter([root_node], _maxDistance,NodeSprite.GRAPH_LINKS); 
			
			vis.operators.add(_gdf); //distance filter has to be added before the layout
			vis.operators.add(lay);

			// Tooltip control
			var dc:DragControl = new DragControl(NodeSprite);
			vis.controls.add(dc);
			
			// Tooltips
			var fmtTT:TextFormat = new TextFormat();
			fmtTT.color = 0x000000;
			fmtTT.size = 14;
			fmtTT.bold = true;
			var ttc:TooltipControl = new TooltipControl(NodeSprite);
			(ttc.tooltip as TextSprite).textFormat = fmtTT;
			
			ttc.addEventListener(TooltipEvent.SHOW,function(evt:TooltipEvent):void {
				if (evt.node.data.web != null) (ttc.tooltip as TextSprite).textField.text = evt.node.data.web;
				if (evt.node.data.address != null) (ttc.tooltip as TextSprite).textField.appendText ('\n'+evt.node.data.address);
				//if (evt.node.data.type != null) (ttc.tooltip as TextSprite).textField.appendText('\nTipo: '+evt.node.data.type);
				//(ttc.tooltip as TextSprite).textField.appendText('\n'+evt.node.degree);
				(ttc.tooltip as TextSprite).render();
			});
			vis.controls.add(ttc);

			sprite.addChild(vis);
			updateRoot(root_node, true);
			
			//call onComplete in mxml app
			onComplete(nodeArray);

			//leyenda
			showText("Independiente",10,480,green);
			showText("Institución",10,500,red);
			showText("Empresa Cultural",10,520,blue);
			showText("<u><a href='http://ypsite.net/capitalreactiva/' target='_blank'>Proyecto Redada</a></u>",10,540,0x222222,200);
			showText("<u><a href='http://www.ypsite.net/' target='_blank'>YProductions</a></u> 2011",10,560,0x222222,200);
			showText("desarrollado por <u><a href='http://go.yuri.at/' target='_blank'>Geraldo</a></u>",10,580,0x222222,200);	
		}
		
		public function getUIComponent():UIComponent {
			return uic;
		}

		public function setCenter(selNode:String,updateList:Boolean):void{
			for (var key:String in vis.data.nodes){
				if (selNode == vis.data.nodes[key].data.name) break;
			}
			updateRoot(vis.data.nodes[key],updateList);
		}
		
		private function showText(text:String,x:int=10,y:int=10,col:uint=0x222222,w:int=100):void{
			var label:TextField = new TextField();
            label.background = true;
            label.backgroundColor = col;
            label.border = false;
            label.x = x;
            label.y = y;
            label.width = w;
            label.height = 18;

            var format:TextFormat = new TextFormat();
            format.font = "Verdana";
            format.color = 0xFFFFFF;
            format.size = 10;

            label.defaultTextFormat = format;
            label.htmlText = text;
            sprite.addChild(label);	
		}
		
		private function update(event:MouseEvent):void {
			var n:NodeSprite = event.target as NodeSprite;
			if (n == null) return; 
			updateRoot(n, true);
		}
		
		private function updateRoot(n:NodeSprite,updateList:Boolean):void {
			vis.data.root = n; 
			_gdf.focusNodes = [n];
			var t1:Transitioner = new Transitioner(_transitionDuration);
			vis.update(t1).play();
			if (updateList) onChange(n.data.name);
			startTimer();
		}

		private function startTimer():void {
			var timer:Timer = new Timer(200,1);
			timer.addEventListener(TimerEvent.TIMER, timerHandler);
			timer.start();
		}
				
		public function timerHandler(event:TimerEvent):void {
        	flare.display.DirtySprite.renderDirty();
        }

		private function getMaxTextLabelWidth() : Number {
			var maxLabelWidth:Number = 0;
			vis.data.nodes.visit(function(n:NodeSprite):void {
				var w:Number = getTextLabelWidth(n);
				if (w > maxLabelWidth) {
					maxLabelWidth = w;
				}
				
			});
			return maxLabelWidth;
		}
		
		private function getMaxTextLabelHeight() : Number {
			var maxLabelHeight:Number = 0;
			vis.data.nodes.visit(function(n:NodeSprite):void {
				var h:Number = getTextLabelHeight(n);
				if (h > maxLabelHeight) {
					maxLabelHeight = h;
				}
				
			});
			return maxLabelHeight;
		}
			
		private function getTextLabelWidth(s:NodeSprite) : Number {
			
			var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
			var b:Rectangle = s2.getBounds(s);
			return s2.width;
		}
		
		private function getTextLabelHeight(s:NodeSprite) : Number {
			var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
			var b:Rectangle = s2.getBounds(s);
			return s2.height;
		}
		
		private function adjustLabel(s:NodeSprite, w:Number, h:Number) : void {
			
			var s2:TextSprite = s.getChildAt(s.numChildren-1) as TextSprite; // get the text sprite belonging to this node sprite
			s2.horizontalAnchor = TextSprite.CENTER;
			s2.verticalAnchor = TextSprite.CENTER;				
		}
		
		private function highLightOn(evt:SelectionEvent):void {
			 _highLight(evt.node,true,1);
		}
			
		private function highlightOff(evt:SelectionEvent):void {
			 _highLight(evt.node,false,1);
		}
			 
		private function _highLight(n:NodeSprite, highlight:Boolean, duration:uint):void {	
			var p:Parallel = new Parallel();	
			var t:Transitioner;
			
			//draw highlighted child nodes
			for (var i:uint = 0; i < n.childDegree; i++ ) {
				var childNode:NodeSprite = n.getChildNode(i) as NodeSprite;
				var childNodeBox:RectSprite = childNode.getChildAt(0) as RectSprite;

				t = getTransitioner(childNode.name, duration); //here we use the name of a node to distingush transitioner tasks
				t.$(childNodeBox).fillColor = highlight ? yellow : getCol(childNode.data.type); 
				t.$(childNodeBox).lineColor = highlight ? yellow : getCol(childNode.data.type); 
				//color depending of connection degree
				//var blue24:uint = 0x000044;
				//t.$(childNodeBox).fillColor = highlight ? yellow : 0xff/0xff*childNode.degree*15 << 24 | blue24;
				p.add(t);
				
				//var childEdge:EdgeSprite = n.getChildEdge(i) as EdgeSprite;
				//childEdge.lineColor = highlight ? yellow : 0x33000044; 
			}
		
			//draw highlighted parent node
			if (n.parentNode != null) {
				var parentNodeBox:RectSprite = n.parentNode.getChildAt(0) as RectSprite;
				t = getTransitioner(n.parentNode.name, duration);
				t.$(parentNodeBox).fillColor = highlight ? yellow : getCol(n.parentNode.data.type); 
				t.$(parentNodeBox).lineColor = highlight ? yellow : getCol(n.parentNode.data.type); 
				//color depending of connection degree
				//t.$(parentNodeBox).fillColor = highlight ? yellow : 0xff/0xff*n.parentNode.degree*15 << 24 | blue24;
				p.add(t);

				//var parentEdge:EdgeSprite = n.parentNode.getChildEdge(i) as EdgeSprite;
				//parentEdge.lineColor = highlight ? yellow : 0x55000044; 
			}

			//draw highlighted node
			var nodeBox:RectSprite = n.getChildAt(0) as RectSprite;
			t = getTransitioner(n.name, duration);
			t.$(nodeBox).fillColor = highlight ? yellow : getCol(n.data.type); 
			t.$(nodeBox).lineColor = highlight ? yellow : getCol(n.data.type); 
			//color depending of connection degree
			//t.$(nodeBox).fillColor = highlight ? yellow : 0xff/0xff*n.degree*15 << 24 | blue24;
			p.add(t);			
			p.play();

			//var edge:EdgeSprite = n.getChildEdge(i) as EdgeSprite;
			//edge.lineColor = highlight ? yellow : 0x77000044; 
		 }
		 
		 private function getCol(type:String = "com"):uint{
		 	var col:uint;
			switch (type){
				case "ins": return(red); break;
				case "ind": return(green); break;
				case "com": 
				default: return(blue);
			}
		 }
		 
		 private function getTransitioner(task:String,duration:Number=1, easing:Function=null,
									 optimize:Boolean = false ):Transitioner {
				if (_trans[task] != null) {					
					_trans[task].stop();
					_trans[task].dispose();
				}							 					 
				_trans[task] = new Transitioner(duration,easing,optimize);
				return _trans[task];
		 }
		 
		private function infoOn(evt:SelectionEvent):void {
			var n:NodeSprite = evt.node;
			//var info:String = "<a href='n.data.web'>"+n.data.web+"</a>";
			var info:String = n.data.web;
			if (n.data.address != null) info+='\n'+n.data.address;
			var fmt:TextFormat = new TextFormat("Verdana",10,0x000000,true);
			fmt.url = n.data.web;
			var ts:TextSprite = new TextSprite();
			ts.name = "info";
			ts.applyFormat(fmt);
			//ts.htmlText = info;
			ts.text = info;
			ts.opaqueBackground = 0xEEEE66;
			ts.x = 10;
			ts.y = 10;
			n.addChild(ts);
			
			if (prev_node != null) prev_node.removeChild(prev_node.getChildByName("info"));
			prev_node = n;
		}
		
		private function gotoWeb(evt:SelectionEvent):void {
			var request:URLRequest = new URLRequest(evt.node.data.web);
			navigateToURL(request,"_BLANK");
		}			
	}
}

/** 
 * graphML reader utility
 * based on code from <a href="http://goosebumps4all.net">martin dudek</a>
 *  */ 
import flare.data.converters.GraphMLConverter;
import flare.data.DataSet;
import flash.events.*;
import flash.net.*;
import flare.vis.data.Data;

class GraphMLReader {
	public var onComplete:Function;

    public function GraphMLReader(onComplete:Function=null,file:String = null) {
        this.onComplete = onComplete;

		if(file != null) {
			read(file);
		}
    }
	
	public function read(file:String):void {
		if ( file != null) {
			var loader:URLLoader = new URLLoader();
			configureListeners(loader);
			var request:URLRequest = new URLRequest(file);
			try {
				loader.load(request);
			} catch (error:Error) {
				trace("Unable to load requested document.");
			}
		}
	}

    private function configureListeners(dispatcher:IEventDispatcher):void {
        dispatcher.addEventListener(Event.COMPLETE, completeHandler);
        dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
        dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
    }

    private function completeHandler(event:Event):void {
		if (onComplete != null) {
			var loader:URLLoader = event.target as URLLoader;
			var dataSet:DataSet = new GraphMLConverter().parse(new XML(loader.data));
			onComplete(Data.fromDataSet(dataSet));
		} else {
			trace("No onComplete function specified.");
		}
    }

    private function securityErrorHandler(event:SecurityErrorEvent):void {
        trace("securityErrorHandler: " + event);
    }
   
    private function ioErrorHandler(event:IOErrorEvent):void {
        trace("ioErrorHandler: " + event);
    }
}