package leveled;

using Lambda;

import yaml.Parser;
import yaml.Yaml;
import yaml.util.ObjectMap;
import thx.Iterables;
import thx.Maps;

class LeveledParser
{
    private var globalData:AnyObjectMap = new AnyObjectMap();

    public function new(gData:String = 'gridSize: 24')
    {
        setGlobalString(gData);
    }

    public function setDefault(data:AnyObjectMap, key:Dynamic, value:Dynamic)
    {
        if (!data.exists(key))
        {
            data.set(key, value);
        }
    }

    public function setGlobalString(data:String)
    {
        setGlobalData(Yaml.parse(data));
    }

    public function setGlobalData(data:AnyObjectMap)
    {
        setDefault(data, 'gridSize', 24);
        setDefault(data, 'layers', new List<Dynamic>());
        setDefault(data, 'objects', new AnyObjectMap());
        setDefault(data, 'defaults', new AnyObjectMap());

        var defaults = data.get('defaults');
        setDefault(defaults, 'width', 1000);
        setDefault(defaults, 'height', 1000);

        var layers:Iterable<Dynamic> = data.get('layers');
        var i = 0;
        for (layer in layers) {
            setDefault(layer, 'type', 'object');
            setDefault(layer, 'name', 'layer-' + i);
            setDefault(layer, 'defaultObject', 'null');
            i ++;
        }

        var gridSize = data.get('gridSize');
        var objects:AnyObjectMap = data.get('objects');
        objects.set('null', new AnyObjectMap());
        for (name in objects.keys()) {
            var object = objects.get(name);

            setDefault(object, 'width', gridSize);
            setDefault(object, 'height', gridSize);
            setDefault(object, 'x', 0);
            setDefault(object, 'y', 0);
            setDefault(object, 'color', '#222222');
            setDefault(object, 'shape', 'rect');
            setDefault(object, 'origin', [object.get('width') / 2, object.get('height') / 2]);
        }

        globalData = data;
    }

    public function parseLevel(data:AnyObjectMap):AnyObjectMap
    {
        setDefault(data, 'layers', new AnyObjectMap());
        setDefault(data, 'gridSize', globalData.get('gridSize'));
        var layers = new AnyObjectMap();
        var globalLayers:Iterable<Dynamic> = globalData.get('layers');

        for (l in globalLayers) {
            var newLayer = new AnyObjectMap();
            var layer:AnyObjectMap = cast (l, AnyObjectMap);

            for (key in layer.keys()) {
                newLayer.set(key, layer.get(key));
            }

            var layerContents:Iterable<Dynamic> = data.get('layers').get(newLayer.get('name'));
            var newLayerContents = new List<AnyObjectMap>();

            if (layerContents != null) {
                for (ob in layerContents) {
                    var object = processLayerObject(newLayer, ob);

                    if (Std.is(object, List)) {
                        for (o in cast (object, List<Dynamic>)) {
                            newLayerContents.add(o);
                        }
                    } else {
                        newLayerContents.add(cast (object, AnyObjectMap));
                    }
                }
            }

            newLayer.set('contents', newLayerContents);

            layers.set(newLayer.get('name'), newLayer);
        }

        data.set('layers', layers);
        return data;
    }

    public function parseLevelString(data:String):AnyObjectMap
    {
        return parseLevel(Yaml.parse(data));
    }

    private function processLayerObject(layer:AnyObjectMap, object:AnyObjectMap):Dynamic
    {
        var placementType = getObjectPlacementType(object);
        var typeName = getAlt(object, 'type', layer.get('defaultObject'));
        var typeObject = getAlt(globalData.get('objects'), typeName, globalData.get('objects').get('null'));
        var gridSize = globalData.get('gridSize');

        var createObject = function () {
            var newObject = new AnyObjectMap();
            
            mergeMap(newObject, typeObject);
            mergeMap(newObject, object);

            return newObject;
        }

        switch (placementType) {
        case 'bitstring':
            var objects = new List<Dynamic>();
            var lines:Iterable<String> = object.get('placement').split(~/[\r\n]+/g);
            var y = 0;
            var x = 0;

            for (line in lines) {

                for (char in line.split('')) {
                    if (char != '.') {
                        var ob = createObject();
                        ob.set('x', ob.get('x') + x * gridSize);
                        ob.set('y', ob.get('y') + y * gridSize);
                        objects.add(ob);
                    }

                    x ++;
                }

                y ++;
            }

            return objects;
        case 'rect':
            var objects = new List<Dynamic>();
            var width = getAlt(object.get('placement'), 'width', 1);
            var height = getAlt(object.get('placement'), 'height', 1);
            var outline = getAlt(object.get('placement'), 'outline', false);

            for (x in 0...width) {
                for (y in 0...height) {
                    if ((!outline) || ((y == 0) || (y == height - 1) || (x == 0) || (x == width - 1))) {

                        var ob = createObject();
                        ob.set('x', ob.get('x') + x * gridSize);
                        ob.set('y', ob.get('y') + y * gridSize);
                        objects.add(ob);
                    }
                }
            }

            return objects;
        }

        return createObject();
    }

    private function getObjectPlacementType(object:AnyObjectMap):String
    {
        if (object.exists('placement')) {
            var placement:Dynamic = object.get('placement');

            if (Std.is(placement, String)) {
                return 'bitstring';
            }

            if ((placement.exists('width')) || (placement.exists('height'))) {
                return 'rect';
            }
        }

        return 'single';
    }

    private function mergeMap(to:AnyObjectMap, from:AnyObjectMap)
    {
        for (key in from.keys()) {
            to.set(key, from.get(key));
        }
    }

    private function getAlt(map:AnyObjectMap, key:String, value:Dynamic)
    {
        return map.exists(key) ? map.get(key) : value;
    }
}
