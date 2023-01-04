from collections import OrderedDict
import re


def to_lua(obj, indent='  ', level=0, sort_keys=False) -> str:
    res = ''

    if obj is None:
        res = "nil"

    elif isinstance(obj, bool):
        res = str(obj).lower()

    elif isinstance(obj, int) or isinstance(obj, float):
        res = str(obj)

    elif isinstance(obj, str):
        obj = obj.replace('\\', '\\\\')
        obj = obj.replace('\n', '\\n')
        if '"' in obj:
            if "'" in obj:
                obj = obj.replace('"', '\\"')
            else:
                res = "'" + obj + "'"
        else:
            res = '"' + obj + '"'

    elif isinstance(obj, list) or isinstance(obj, tuple):
        res = '{\n'
        for value in obj:
            res += indent * (level + 1) + to_lua(value, indent=indent, level=level + 1, sort_keys=sort_keys) + ',\n'
        res += indent * level + '}'

    elif isinstance(obj, dict) or isinstance(obj, OrderedDict):
        res = '{\n'
        items = obj.items()
        if sort_keys:
            items = sorted(items)

        bracked = False
        if len(obj.keys()) > 0:
            num_simple_keys = 0
            for key in obj.keys():
                if isinstance(key, str) and re.match(r'^[a-zA-Z_]\w*$', key):
                    num_simple_keys += 1
            if num_simple_keys / len(obj.keys()) < 0.3:
                bracked = True

        for key, value in items:
            if bracked or not (isinstance(key, str) and re.match(r'^[a-zA-Z_]\w*$', key)):
                key = '[' + to_lua(key, indent=indent, level=level + 1, sort_keys=sort_keys) + ']'
            value = to_lua(value, indent=indent, level=level + 1, sort_keys=sort_keys)
            res += indent * (level + 1) + key + ' = ' + value + ',\n'
        res += indent * level + '}'

    else:
        raise ValueError(f'Unrecognized type "{type(obj)}"')

    return res



def dumps(obj, indent=None, sort_keys=False):
    if indent is None:
        indent = '  '
    elif type(indent) == int:
        indent = ' ' * indent
    elif type(indent) != str:
        indent = '  '
    return to_lua(obj, indent=indent, level=0, sort_keys=sort_keys)


def dump(obj, fp, indent=None, sort_keys=False):
    fp.write(dumps(obj, indent=indent, sort_keys=sort_keys))
