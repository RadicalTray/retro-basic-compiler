from sklearn.metrics import r2_score
from labellines import labelLines
import matplotlib.pyplot as plt
import scipy.stats as stats
import seaborn as sns
import pandas as pd
import numpy as np
import json

idx = 3
with open('./cyk' + str(idx) + '.json') as f:
    cyk = json.load(f)

with open('./earley' + str(idx) + '.json') as f:
    earley = json.load(f)

def m(x):
    return list(map(lambda y: y['num_tokens'], x['data'])), list(map(lambda y: y['time_ns']/y['iterations'], x['data']))

x1, y1 = m(cyk)
x2, y2 = m(earley)

fig, ax = plt.subplots()

# CYK
model = np.poly1d(np.polyfit(x1, y1, 3))
print(r2_score(y1, model(x1)))
polyline = np.linspace(x1[0], x1[-1], len(x1))
ax.scatter(x1, y1, color='y', label='CYK')
ax.plot(polyline, model(polyline), color='r', label='CYK')

# Earley
model = np.poly1d(np.polyfit(x2, y2, idx))
print(r2_score(y2, model(x2)))
polyline = np.linspace(x2[0], x2[-1], len(x2))
ax.scatter(x2, y2, color='c', label='Earley')
ax.plot(polyline, model(polyline), color='b', label='Earley')

plt.xlabel('Input Size')
plt.ylabel('Time (ns)')
plt.legend()

lines = plt.gca().get_lines()
labelLines(lines, xvals=[x1[len(x1)//2], x2[len(x2)//2]])

plt.show()
