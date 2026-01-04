import re
import os

def parse(filename):
    file = open(filename, "r")

    nextline = file.readline()
    while not re.match(r"The following parameter values will be used", nextline):
        nextline = file.readline()
        if nextline == "":
            return []

    values = {}
    while not re.match(r"-+", nextline):
        nextline = file.readline()
        if nextline == "":
            return []
        match = re.match(r"(.*):(.*)", nextline)
        if match == None:
            continue
        arg = match.group(1).strip()
        val = match.group(2).strip()
        if arg not in ("PMAP", "SWAP", "L1", "U", "EQUIL", "ALIGN"):
            val = [s.strip() for s in val.split(" ")]
            val = [v for v in val if v != ""]
        values[arg] = val

    names = ["T/V","N","NB","P","Q","Time","Gflops"]
    dataTypes = [str, int, int, int, int, float, float]
    index = 0
    runs = []
    while nextline != "":
        nextline = file.readline()
        match = re.match(r"T\/V +N +NB +P +Q +Time +Gflops", nextline)
        if match == None:
            continue
        file.readline()
        nextline = file.readline()
        vals = [v.strip() for v in nextline.split(" ")]
        vals = [v for v in vals if v != ""]
        entry = {name : dType(val) for name, val, dType in zip(names, vals, dataTypes)}
        entry["index"] = index
        index += 1
        runs.append(entry)

    file.close()

    if len(runs) == 0:
        return []

    best = sorted(runs, key = lambda x:x["Gflops"], reverse=True)
    with open(filename+".res", "w") as file:
        file.write("\n".join([f"{k:<15}: {str(v)}" for k, v in values.items()]))
        file.write("\n\nsorted:\n")
        file.write("         "+"".join([f"{n:<13}" for n in names])+"\n")
        for r in best:
            file.write(f"run {r["index"]:<3}  ")
            file.write("".join([f"{str(r[k]):<13}" for k in names]))
            file.write("\n")

        file.write("\n\nunsorted:\n")
        file.write("         "+"".join([f"{n:<13}" for n in names])+"\n")
        for r in runs:
            file.write(f"run {r["index"]:<3}  ")
            file.write("".join([f"{str(r[k]):<13}" for k in names]))
            file.write("\n")
    
    return runs

root = "output"
outfiles = [os.path.join(root, file) for file in os.listdir(root) if re.match(r".*\.out$", file)]
runs = []
for file in outfiles:
    run = parse(file)
    for r in run:
        r["run"] = file
    runs += run

names = ["run","index","T/V","N","NB","P","Q","Time","Gflops"]
best = sorted(runs, key = lambda x:x["Gflops"], reverse=True)
padding = 3
ns = [max([len(str(r[n])) for r in runs]+[len(n)])+padding for n in names]
with open("BESTRUNS.txt", "w") as file:
    file.write("".join([f"{n:<{ns[k]}}" for k,n in enumerate(names)])+"\n")
    for r in best:
        file.write("".join([f"{str(r[n]):<{ns[k]}}" for k,n in enumerate(names)]))
        file.write("\n")
