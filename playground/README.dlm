2013-09-30

doslo misto a bohuzel jsem si smazal cele readme s vysledky.

Nicmene jsem aspon neco nasel.

20k	s.dlm.ea107c2d.20130928-1535	DONE	testLOSS	0.392599	ALILencs-gdfa ALISczeng CORPczeng20k CORPczengdev20k srcctxCORPczeng20k/en" srcctxCORPczengdev20k/en"
40k	s.dlm.64e27f4e.20130929-1521	DONE	testLOSS	0.372073	ALILencs-gdfa ALISczeng CORPczeng40k CORPczengdev20k srcctxCORPczeng40k/en" srcctxCORPczengdev20k/en"
100k	s.dlm.80861839.20130929-1522	DONE	testLOSS	 0.34743	ALILencs-gdfa ALISczeng CORPczeng100k CORPczengdev20k srcctxCORPczeng100k/en" srcctxCORPczengdev20k/en"
	
20k	s.dlm.e7ffb123.20130928-0117	DONE	testLOSS	0.108243	ALILencs-gdfa ALISczeng CORPczeng20k srcctxCORPczeng20k/en"
40k	s.dlm.1457b1a5.20130928-0124	DONE	testLOSS	0.118534	ALILencs-gdfa ALISczeng CORPczeng40k srcctxCORPczeng40k/en"
100k	s.dlm.3de8c992.20130928-0124	DONE	testLOSS	0.124231	ALILencs-gdfa ALISczeng CORPczeng100k srcctxCORPczeng100k/en"
	
20k	s.dlm.9e6d481b.20130927-1601	DONE	testLOSS	0.101769	ALILen-lemma-cs-lemma ALISgdfa CORPczeng20k srcctxCORPczeng20k/en"
20k	s.dlm.f09f5aa3.20130927-1557	DONE	testLOSS	0.101853	ALILen-lemma-cs-lemma ALISgdfa CORPczeng20k srcctxCORPczeng20k/en"


2013-09-30

Zjistil jsem, ze jsem dosud bral jen malo vstupnich faktoru, zadne podrobne od
Marion.

Ovsem ukazuje se, ze to nebylo prilis mnoho dodatecne informace, protoze zagzipovany vw-input.gz je velky:
338M  ...s temi vsemi faktory
294M  ...jen se zakladnim form+lemma+tag

Co kdyz budu predikovat z jeste mene, jen z formy?
s.dlm.b8361132.20130930-1844 ... jen z formy
s.dlm.3cd30400.20130930-1845 ... jen z lemmatu
s.dlm.83748196.20130930-1846 ... jen z tagu
s.dlm.9fe895dc.20130930-0042 ... forma+lemma+tag
s.dlm.316bdfdc.20130930-1738 ... forma+lemma+tag+vse od marion
  a jeste varianta s 40passes: s.dlm.26833812.20131001-0107


Zkusim s.dlm.9fe895dc.20130930-0042 (0.392578) upravit tak, aby predikoval jenom tag slova.
-> s.dlm.039df11b.20131001-0110 ... 0.31646 cili zatim nejlepsi vysledek...predikuje se tag ze celeho okoli *tagu*, nikoli forem
a toho variantu, ktera bude predikovat:
s.dlm.1410dc5f.20131001-0112 ... ze vsech vstupnich
s.dlm.ebc88921.20131001-1106 ... z tagu
s.dlm.bbe6fd29.20131001-1108 ... z formy
s.dlm.b3a55342.20131001-1108 ... z lemmatu
s.dlm.92264312.20131001-1110 ... z formy+lemmatu+tagu


