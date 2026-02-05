# mc_coffe
Hai bisogno di una pausa caffe senza che teams allerti tutto il vicinato? Ci penso io!
## Percorso
Il tool può essere posizionato in qualsiasi cartella. Per l'esempio assumiamo che `coffe.swift` sia nella cartella corrente.

## Compilazione
```
swiftc -framework IOKit -framework CoreFoundation coffe.swift -o coffe
```

## Installazione (PATH)
Aggiungi la cartella corrente al PATH in modo che `coffe` sia richiamabile da qualsiasi directory:

```
echo 'export PATH="$(pwd):$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## Utilizzo
```
coffe
```

## Descrizione breve
`coffe` mantiene il Mac attivo impedendo standby e spegnimento del monitor e simulando attività utente. Interrompere con `Ctrl+C` per ripristinare il comportamento normale.

## Avanzato
Breve: coffe crea un'asserzione IOPM per impedire standby e tiene il monitor acceso; inoltre simula attività utente muovendo il mouse a intervalli regolari e può arrestarsi automaticamente a un orario configurabile.

### Modalità e parametri
| Opzione | Effetto | Valori |
|---|---:|---|
| nessuna | Comportamento di default: crea asserzione, muove il mouse ogni 12s, auto-stop alle 18:10 | — |
| -t false | Disabilita l'arresto automatico (rimane attivo fino a chiusura manuale) | `-t false` |
| -t HH MM | Imposta orario di auto-stop (se già passato oggi → domani) | `-t 21 30` (es.) |
| Ctrl+C (SIGINT) | Rilascia asserzione e termina pulito | Interazione utente |
| argomenti non validi | Messaggio su stderr ed exit con failure | — |

### Dettagli tecnici (non nel sommario)
- Auto-stop predefinito: 18:10 (configurabile con `-t`).
- Intervallo movimento mouse: ogni 12 secondi; spostamento ±1 punto sull'asse X.
- Aggiornamento a riga di stato con timestamp (dateStyle .short / timeStyle .medium).
- Formato visuale dell'orario di stop: `HH:mm dd/MM`.
- Usa DispatchSourceTimer e RunLoop.main per scheduling.
- Gestione segnale SIGINT per rilascio pulito dell'asserzione IOPM.
- Potrebbe richiedere permessi di Accessibilità / Input Monitoring per inviare eventi di mouse su macOS.
- Errori nella creazione dell'asserzione o argomenti errati vengono riportati su stderr e fanno terminare il programma.
