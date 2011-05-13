#Anything in this file, followed by a period (and an upper-case word), does NOT indicate an end-of-sentence marker.
#Special cases are included for prefixes that ONLY appear before 0-9 numbers.

#any single upper case letter  followed by a period is not a sentence ender
#usually upper case letters are initials in a name
A
Á
B
C
Č
D
Ď
E
É
F
G
H
I
Í
J
K
L
Ľ
M
N
Ň
O
Ó
P
Q
R
Ř
S
Š
T
Ť
U
Ú
V
W
X
Y
Ý
Z
Ž

#List of titles. These are often followed by upper-case names, but do not indicate sentence breaks
p
pí
sl
s
br
ing
Ing
bc
Bc
mgr
Mgr
dr
Dr
doc
Doc
prof
Prof
RNDr
PhDr
MUDr
JUDr
RSDr
maj
Maj
mjr
Mjr
poruč
Poruč
ppor
Ppor
npor
Npor
plk
Plk
pplk
Pplk
gen
Gen
adm
Adm
guv
Guv
kpt
Kpt
kap
Kap

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
