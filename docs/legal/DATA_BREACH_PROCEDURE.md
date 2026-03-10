# Procedura Data Breach - Nova App

**Versione:** 1.0.0
**Data:** 9 marzo 2026
**Riferimento:** Art. 33-34 GDPR, Art. 2-bis D.Lgs. 101/2018

---

## 1. Definizione di Data Breach

Un data breach (violazione dei dati personali) è una violazione di sicurezza che comporta:
- Distruzione accidentale o illecita di dati personali
- Perdita di dati personali
- Modifica non autorizzata di dati personali
- Divulgazione non autorizzata di dati personali
- Accesso non autorizzato ai dati personali

### 1.1 Esempi di Data Breach

| Tipo | Esempio |
|------|---------|
| **Confidenzialità** | Accesso non autorizzato al database, leak di credenziali |
| **Integrità** | Modifica non autorizzata di profili utente |
| **Disponibilità** | Ransomware, cancellazione accidentale di backup |

---

## 2. Fasi della Procedura

### Fase 1: Rilevamento e Contenimento (0-2 ore)

**Responsabile:** Team Tecnico

1. **Identificare** la natura della violazione
2. **Contenere** immediatamente la minaccia:
   - Disconnettere sistemi compromessi
   - Revocare credenziali compromesse
   - Bloccare accessi sospetti
3. **Documentare** tutto in tempo reale:
   - Timestamp del rilevamento
   - Sistemi coinvolti
   - Dati potenzialmente esposti
   - Azioni intraprese

### Fase 2: Valutazione del Rischio (2-6 ore)

**Responsabile:** DPO / Responsabile Privacy

1. **Determinare** la gravità:
   - Numero di utenti coinvolti
   - Tipologia di dati esposti
   - Probabilità di danno agli interessati

2. **Classificare** il rischio:

| Livello | Descrizione | Azione |
|---------|-------------|--------|
| **BASSO** | Dati non sensibili, improbabile identificazione | Solo registro interno |
| **MEDIO** | Rischio probabile per diritti utenti | Notifica al Garante |
| **ALTO** | Rischio elevato (minori, dati sensibili) | Notifica Garante + utenti |

### Fase 3: Notifica al Garante (entro 72 ore)

**Responsabile:** DPO / Titolare del Trattamento

Se il rischio è MEDIO o ALTO, notificare al Garante Privacy entro **72 ore** dal rilevamento.

**Canale di notifica:**
- Portale online: https://www.garanteprivacy.it/web/guest/home/docweb/-/docweb-display/docweb/9128501
- Email PEC: protocollo@pec.gpdp.it

**Contenuto della notifica (Art. 33 GDPR):**
- [ ] Natura della violazione
- [ ] Categorie e numero approssimativo di interessati
- [ ] Categorie e numero approssimativo di dati coinvolti
- [ ] Nome e contatti del DPO
- [ ] Probabili conseguenze della violazione
- [ ] Misure adottate o proposte per rimediare

### Fase 4: Notifica agli Utenti (se rischio ALTO)

**Responsabile:** Team Comunicazione + Tecnico

Se il rischio per gli interessati è **elevato**, notificare direttamente gli utenti.

**Canali di notifica (in ordine di priorità):**
1. Push notification in-app
2. Email agli indirizzi registrati
3. Banner in-app al prossimo accesso

**Template notifica utente:**

```
Oggetto: Avviso di sicurezza importante - Nova

Gentile [Nome],

Ti informiamo che abbiamo rilevato un incidente di sicurezza
che potrebbe aver coinvolto i seguenti dati del tuo account:
- [Lista dati coinvolti]

Cosa abbiamo fatto:
- [Azioni di contenimento]
- [Misure di protezione implementate]

Cosa ti consigliamo di fare:
- [Azioni raccomandate per l'utente]

Per qualsiasi domanda: privacy@nova-app.it

Il Team Nova
```

### Fase 5: Documentazione e Registro

**Responsabile:** DPO

1. **Aggiornare** il Registro delle Violazioni con:
   - Descrizione completa dell'incidente
   - Dati coinvolti
   - Effetti della violazione
   - Misure di rimedio adottate
   - Esito delle notifiche

2. **Archiviare** tutta la documentazione per almeno **5 anni**

---

## 3. Contatti di Emergenza

| Ruolo | Nome | Contatto |
|-------|------|----------|
| **Titolare del Trattamento** | <!-- TODO: Inserire --> | privacy@nova-app.it |
| **DPO** | <!-- TODO: Nominare DPO --> | dpo@nova-app.it |
| **Team Tecnico** | Lead Developer | <!-- TODO: Inserire --> |
| **Garante Privacy** | - | protocollo@pec.gpdp.it |

---

## 4. Checklist Data Breach

### Rilevamento
- [ ] Violazione confermata
- [ ] Timestamp rilevamento registrato
- [ ] Team tecnico allertato
- [ ] Contenimento iniziato

### Valutazione (entro 24h)
- [ ] Sistemi coinvolti identificati
- [ ] Dati esposti catalogati
- [ ] Numero utenti coinvolti stimato
- [ ] Livello rischio determinato (BASSO/MEDIO/ALTO)

### Notifica Garante (se necessaria, entro 72h)
- [ ] Notifica preparata
- [ ] Notifica inviata via portale/PEC
- [ ] Ricevuta di conferma archiviata

### Notifica Utenti (se rischio ALTO)
- [ ] Template messaggio preparato
- [ ] Push notification inviata
- [ ] Email inviata
- [ ] Banner in-app attivato

### Post-Incidente
- [ ] Registro violazioni aggiornato
- [ ] Root cause analysis completata
- [ ] Misure preventive implementate
- [ ] Report finale redatto

---

## 5. Edge Function per Notifica Massiva

Per inviare notifiche data breach agli utenti, utilizzare:

```bash
# Deploy della funzione
npx supabase functions deploy send-data-breach-notification

# Invio notifica (solo da dashboard con service role)
curl -X POST \
  'https://YOUR_PROJECT.supabase.co/functions/v1/send-data-breach-notification' \
  -H 'Authorization: Bearer SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "affected_user_ids": ["uuid1", "uuid2"],
    "breach_type": "unauthorized_access",
    "affected_data": ["email", "full_name"],
    "message": "Descrizione dell'\''incidente..."
  }'
```

---

## 6. Riferimenti Normativi

- **Art. 33 GDPR** - Notifica di violazione all'autorità di controllo
- **Art. 34 GDPR** - Comunicazione di violazione all'interessato
- **Art. 2-bis D.Lgs. 101/2018** - Disposizioni integrative italiane
- **Linee Guida WP250** - Guidelines on Personal data breach notification

---

**Documento approvato da:** <!-- TODO: Firma responsabile -->
**Data approvazione:** <!-- TODO: Data -->
**Prossima revisione:** <!-- TODO: Data + 12 mesi -->
