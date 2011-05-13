#Anything in this file, followed by a period (and an upper-case word), does NOT indicate an end-of-sentence marker.
#Special cases are included for prefixes that ONLY appear before 0-9 numbers.

#any single upper case letter  followed by a period is not a sentence ender
#usually upper case letters are initials in a name
A
B
C
Č
D
E
F
G
H
I
J
K
L
M
N
O
P
Q
R
Ř
S
Š
T
U
V
W
X
Y
Z
Ž

#List of titles. These are often followed by upper-case names, but do not indicate sentence breaks
p
pí
sl
s
br
ing
bc
mgr
dr
doc
prof
Prof
RNDr
PhDr
MUDr
JUDr
RSDr
maj
mjr
poruč
ppor
npor
plk
pplk
gen
adm
guv
kpt
kap

#misc - odd period-ending items that NEVER indicate breaks (p.m. does NOT fall into this category - it sometimes ends a sentence)
v
vs
tj
mj
m.j
např
kupř
popř
příp

#Numbers only. These should only induce breaks when followed by a numeric sequence
# add NUMERIC_ONLY after the word for this function
#This case is mostly for the english "No." which can either be a sentence of its own, or
#if followed by a number, a non-breaking prefix
č #NUMERIC_ONLY# 
odst
písm
str #NUMERIC_ONLY#
