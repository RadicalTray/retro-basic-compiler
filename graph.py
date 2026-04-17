from sklearn.metrics import r2_score
from labellines import labelLines
import matplotlib.pyplot as plt
import scipy.stats as stats
import seaborn as sns
import pandas as pd
import numpy as np
import json

with open('./cyk1.json') as f:
    cyk1 = json.load(f)
with open('./earley1.json') as f:
    earley1 = json.load(f)
with open('./cyk2.json') as f:
    cyk2 = json.load(f)
with open('./earley2.json') as f:
    earley2 = json.load(f)
with open('./cyk3.json') as f:
    cyk3 = json.load(f)
with open('./earley3.json') as f:
    earley3 = json.load(f)

def m(x):
    return list(map(lambda y: y['num_tokens'], x['data'])), list(map(lambda y: y['time_ns']/y['iterations'], x['data']))

x1, y1 = m(cyk1)
x5, y5 = m(cyk2)
x6, y6 = m(cyk3)
x2, y2 = m(earley1)
x3, y3 = m(earley2)
x4, y4 = m(earley3)

fig, ax = plt.subplots()

# CYK
model = np.poly1d(np.polyfit(x1, y1, 3))
print(r2_score(y1, model(x1)))
polyline = np.linspace(x1[0], x1[-1], len(x1))
ax.scatter(x1, y1, color='y', label='CYK')
ax.plot(polyline, model(polyline), color='r', label='CYK 1')

model = np.poly1d(np.polyfit(x5, y5, 3))
print(r2_score(y5, model(x5)))
polyline = np.linspace(x5[0], x5[-1], len(x5))
ax.scatter(x5, y5, color='y', label='CYK')
ax.plot(polyline, model(polyline), color='r', label='CYK 2')

model = np.poly1d(np.polyfit(x6, y6, 3))
print(r2_score(y6, model(x6)))
polyline = np.linspace(x6[0], x6[-1], len(x6))
ax.scatter(x6, y6, color='y', label='CYK')
ax.plot(polyline, model(polyline), color='r', label='CYK 3')

# Earley
model = np.poly1d(np.polyfit(x2, y2, 1))
print(r2_score(y2, model(x2)))
polyline = np.linspace(x2[0], x2[-1], len(x2))
ax.scatter(x2, y2, color='c', label='Earley 1')
ax.plot(polyline, model(polyline), color='b', label='Earley 1')

model = np.poly1d(np.polyfit(x3, y3, 2))
print(r2_score(y3, model(x3)))
polyline = np.linspace(x3[0], x3[-1], len(x3))
ax.scatter(x3, y3, color='c', label='Earley 2')
ax.plot(polyline, model(polyline), color='b', label='Earley 2')

model = np.poly1d(np.polyfit(x4, y4, 3))
print(r2_score(y4, model(x4)))
polyline = np.linspace(x4[0], x4[-1], len(x4))
ax.scatter(x4, y4, color='c', label='Earley 2')
ax.plot(polyline, model(polyline), color='b', label='Earley 3')

plt.xlabel('Input Size')
plt.ylabel('Time (ns)')
plt.legend()

lines = plt.gca().get_lines()
labelLines(lines, xvals=[x1[len(x1)//2], x2[len(x2)//2], x3[len(x3)//2], x4[len(x4)//2], x5[len(x5)//2], x6[len(x6)//2]])

plt.show()
