from collections import OrderedDict
import json
import re
import os
import glob
import warnings

import luadata


def add_code_point_command(latex_data, code_point, command):
    unicode_data = latex_data['unicode']
    unicode_commands = latex_data['unicode_commands']

    if code_point not in unicode_data:
        unicode_data[code_point] = command

    if command not in unicode_commands:
        unicode_commands[command] = code_point


def get_texmf_dist_path():
    paths = glob.glob('/usr/local/texlive/*/texmf-dist')
    if paths:
        return sorted(paths)[-1]
    else:
        raise ValueError


def strip_braces(s):
    return re.sub(r'^\{(.*)\}$', r'\1', s)


def load_tuenc_def(latex_data, texmf_dist):
    unicode_data = latex_data['unicode']
    unicode_commands = latex_data['unicode_commands']

    tuenc_path = os.path.join(texmf_dist, 'tex', 'latex', 'base', 'tuenc.def')
    with open(tuenc_path) as f:
        lines = f.readlines()

    for line in lines:
        line = line.strip()
        cs_regex = r'\\(?:[A-Za-z]+|[^A-Za-z])'
        arg_regex = r'(\{[^}]*\}|' + cs_regex + r')'
        line_regex = rf'\\DeclareUnicodeSymbol\s*{arg_regex}\s*' + r'\{(.*)\}'
        matched = re.match(line_regex, line)
        if matched:
            command = strip_braces(matched.group(1))
            code_point = strip_braces(matched.group(2))
            code_point = code_point.replace('\\remove@tlig{', '').replace('}', '')
            code_point = code_point.replace('"', '')
            if command not in unicode_commands:
                unicode_commands[command] = code_point
            continue

        # matched = re.match(rf'\\DeclareUnicodeAccent\s*{arg_regex}\s*{arg_regex}', line)
        # if matched:
        #     command = matched.group(1)
        #     code_point = matched.group(2)
        #     code_point = code_point.replace('"', '')
        #     if command not in unicode_commands:
        #         unicode_commands[command] = dict()
        #     unicode_commands[command]['code_point'] = code_point
        #     continue

        matched = re.match(rf'\\DeclareUnicodeComposite\s*{arg_regex}\s*{arg_regex}\s*{arg_regex}', line)
        if matched:
            command = strip_braces(matched.group(1))
            argument = strip_braces(matched.group(2))
            code_point = strip_braces(matched.group(3))
            code_point = code_point.replace('"', '')
            if command not in unicode_commands:
                unicode_commands[command] = dict()
            if argument not in unicode_commands[command]:
                unicode_commands[command][argument] = code_point
            continue


def load_utf8enc_dfu(latex_data, texmf_dist):
    tuenc_path = os.path.join(texmf_dist, 'tex', 'latex', 'base', 'utf8enc.dfu')
    with open(tuenc_path) as f:
        lines = f.readlines()

    unicode_data = latex_data['unicode']
    unicode_commands = latex_data['unicode_commands']

    for line in lines:
        line = line.strip()
        line_regex = r'\\DeclareUnicodeCharacter\s*\{([^}]*)\}\s*\{(.*)\}'
        matched = re.match(line_regex, line)
        if matched:
            code_point = matched.group(1)
            command = matched.group(2)

            if '\\cyr' in command or '\\CYR' in command:
                continue

            command = command.replace('\\@tabacckludge', '\\')

            if code_point not in unicode_data:
                unicode_data[code_point] = command

            cmd_arg = re.match(r'^(\\(?:[a-zA-Z]+|[^a-zA-Z]))\s*(.*?)$', command)

            if cmd_arg:
                command = cmd_arg.group(1)
                argument = cmd_arg.group(2)

                if argument:
                    argument = strip_braces(argument)
                    # if argument == '':
                    #     print(code_point)
                    #     print(command)
                    #     print(argument)

                    if command.startswith('\\if'):
                        continue
                    if argument.startswith('\\cyr') or argument.startswith('\\CYR'):
                        continue

                    if command not in unicode_commands:
                        unicode_commands[command] = dict()
                    if argument not in unicode_commands[command]:
                        unicode_commands[command][argument] = code_point
                else:
                    if command not in unicode_commands:
                        unicode_commands[command] = code_point

            continue



def get_latex_data():
    latex_data = {
        'unicode': dict(),
        'unicode_commands': dict(),
    }

    # Special commands
    add_code_point_command(latex_data, '0023', '\\#')
    add_code_point_command(latex_data, '0024', '\\$')
    add_code_point_command(latex_data, '0025', '\\%')
    add_code_point_command(latex_data, '0026', '\\&')
    add_code_point_command(latex_data, '005C', '\\textbackslash')
    add_code_point_command(latex_data, '005F', '\\_')

    add_code_point_command(latex_data, '007B', '\\{')
    add_code_point_command(latex_data, '007D', '\\}')

    add_code_point_command(latex_data, '00AD', '\\-')
    add_code_point_command(latex_data, '2003', '\\quad')
    add_code_point_command(latex_data, 'FEFF', '\\nobreak')

    texmf_dist = get_texmf_dist_path()

    load_tuenc_def(latex_data, texmf_dist)

    load_utf8enc_dfu(latex_data, texmf_dist)

    # source2e b ltplain.dtx  1 Plain TeX

    # \def\lq{`}
    add_code_point_command(latex_data, '2018', '\\lq')
    # \def\rq{'}
    add_code_point_command(latex_data, '2019', '\\rq')
    # \def\lbrack{[}
    add_code_point_command(latex_data, '005B', '\\lbrack')
    # \def\rbrack{]}
    add_code_point_command(latex_data, '005D', '\\rbrack')
    # \def \aa {\r a}
    add_code_point_command(latex_data, '00E5', '\\aa')
    # \def \AA {\r A}
    add_code_point_command(latex_data, '00C5', '\\AA')
    # \def\space{ }
    add_code_point_command(latex_data, '0020', '\\space')
    # \let\bgroup={
    add_code_point_command(latex_data, '007B', '\\bgroup')
    # \let\egroup=}
    add_code_point_command(latex_data, '007D', '\\egroup')

    return latex_data



if __name__ == '__main__':
    latex_data_json_path = 'scripts/citeproc-latex-data.json'
    latex_data_lua_path = 'citeproc/citeproc-latex-data.lua'

    with open(latex_data_json_path) as f:
        latex_data = json.load(f)

    new = get_latex_data()

    latex_data['unicode'] = new['unicode']
    latex_data['unicode_commands'] = new['unicode_commands']

    with open(latex_data_json_path, 'w') as f:
        json.dump(latex_data, f, indent=4, ensure_ascii=False, sort_keys=True)
        f.write('\n')

    with open(latex_data_lua_path, 'w') as f:
        f.write('return ')
        luadata.dump(latex_data, f, sort_keys=True)
        f.write('\n')
