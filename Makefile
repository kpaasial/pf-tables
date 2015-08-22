.SUFFIXES: .sh .sh.in

.sh.in.sh:
	sed -e "s|@@PREFIX@@|${PREFIX}|g" < ${.ALLSRC} > ${.TARGET}

PREFIX?=/usr/local


SCRIPTS= pf-tables.sh
ETCFILES= pf-tables.conf.sample

all: ${SCRIPTS}

install: install-scripts install-etc

install-scripts:	${SCRIPTS}
	${INSTALL} -m 755 $> ${DESTDIR}/${PREFIX}/sbin 

install-etc:	${ETCFILES}
	${INSTALL} -m 640 $> ${DESTDIR}/${PREFIX}/etc

pf-tables.sh: pf-tables.sh.in

clean:
	-rm ${SCRIPTS}
