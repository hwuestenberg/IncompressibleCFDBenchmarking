#!/usr/bin/env python3
"""Check the mesh/restart and all paired IFW sessions before a run."""
import argparse
import re
import sys
from pathlib import Path
import xml.etree.ElementTree as ET


def ids(spec, prefix):
    match = re.fullmatch(rf'{prefix}\[([0-9, ]+)\]', spec.strip())
    if not match:
        raise ValueError(f'Invalid {prefix} reference: {spec!r}')
    return {int(item) for item in match.group(1).split(',')}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    case = Path(__file__).resolve().parent.parent
    mesh = args.source/'mesh/eifw-3d.xml'
    restart = args.source/'restart_ctu_306.fld'
    try:
        composites = set()
        with mesh.open() as source:
            for line in source:
                match = re.search(r'<C ID="(\d+)"', line)
                if match:
                    composites.add(int(match.group(1)))
                if '</COMPOSITE>' in line:
                    break
        if not {0, 2, *range(3, 13)} <= composites:
            raise ValueError(f'Mesh composites incomplete: {sorted(composites)}')
        info = ET.parse(restart/'Info.xml').getroot()
        partitions = info.findall('Partition')
        if len(partitions) != 128:
            raise ValueError(f'Expected 128 restart partitions, found {len(partitions)}')
        for part in partitions:
            if not (restart/part.get('FileName')).is_file():
                raise ValueError(f'Missing restart partition: {part.get("FileName")}')
        baseline = None
        for path in (case/'session-legacy.xml', case/'session-redesign.xml'):
            root = ET.parse(path).getroot()
            conditions = root.find('CONDITIONS')
            referenced = set()
            for expansion in root.findall('./EXPANSIONS/E'):
                referenced.update(ids(expansion.get('COMPOSITE'), 'C'))
            regions = {}
            for region in conditions.findall('./BOUNDARYREGIONS/B'):
                regions[int(region.get('ID'))] = ids(region.text, 'C')
                referenced.update(regions[int(region.get('ID'))])
            if not referenced <= composites:
                raise ValueError(f'{path.name}: missing composites {sorted(referenced-composites)}')
            bcids = {int(region.get('REF')) for region in conditions.findall('./BOUNDARYCONDITIONS/REGION')}
            if bcids != set(regions):
                raise ValueError(f'{path.name}: boundary condition IDs do not match regions')
            forces = root.findall('./FILTERS/FILTER')
            if len(forces) != 4 or any(item.get('TYPE') != 'AeroForces' for item in forces):
                raise ValueError(f'{path.name}: expected four AeroForces filters')
            for filt in forces:
                values = {param.get('NAME'): (param.text or '').strip() for param in filt.findall('PARAM')}
                if not ids(values['Boundary'], 'B') <= set(regions):
                    raise ValueError(f'{path.name}: force filter references unknown boundary')
            initial = conditions.find("./FUNCTION[@NAME='InitialConditions']/F")
            if initial is None or initial.get('FILE') != 'restart_ctu_306.fld':
                raise ValueError(f'{path.name}: wrong restart reference')
            physical = tuple(ET.tostring(root.find(tag)) for tag in (
                'EXPANSIONS', './CONDITIONS/PARAMETERS', './CONDITIONS/VARIABLES',
                './CONDITIONS/BOUNDARYREGIONS', './CONDITIONS/BOUNDARYCONDITIONS',
                "./CONDITIONS/FUNCTION[@NAME='InitialConditions']", 'FILTERS'))
            if baseline is None:
                baseline = physical
            elif physical != baseline:
                raise ValueError(f'{path.name}: physical setup differs from the other sessions')
            print(f'{path.name}: composites, boundary conditions, forces, and restart valid')
        print(f'Mesh: {len(composites)} composites; restart: {len(partitions)} partitions at time {info.findtext("./Metadata/Time")}')
    except (OSError, ET.ParseError, ValueError, KeyError) as exc:
        parser.exit(1, f'error: {exc}\n')


if __name__ == '__main__':
    main()
