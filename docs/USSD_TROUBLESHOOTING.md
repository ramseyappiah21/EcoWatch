# Fix: "Dear customer, the network is experiencing technical problems..."

Africa's Talking shows that message when **it cannot get a valid reply from your Callback URL**
(timeout, 502, HTML error page, or response that does not start with `CON` / `END`).

EcoWatch's webhook **does work** when Render is awake. Tested reply:

```text
CON Welcome to EcoWatch Tarkwa
1. Report Incident
2. Track Report
3. Privacy Information
4. Help
```

## Do this now (in order)

### 1. Set the exact Callback URL in Africa's Talking

Dashboard → **USSD** → your channel → **Callback URL**:

```text
https://ecowatch-wu20.onrender.com/v1/ussd/webhook
```

Must be **https**, must include `/v1/ussd/webhook`, no trailing slash after webhook.

Save / update the channel.

### 2. Wake Render BEFORE opening the simulator

Open in a browser and wait until you see JSON with `"status":"ok"`:

```text
https://ecowatch-wu20.onrender.com/health
```

If this takes 30–60 seconds, that is normal on free tier.  
**Then** open the AT simulator (not before).

### 3. Keep it awake during the defense

In PowerShell:

```powershell
cd C:\Users\ramse\source\repos\EcoWatch\backend
powershell -File scripts\keep-render-awake.ps1
```

Leave that window open.

### 4. Use the Sandbox Simulator (not a real phone)

Sandbox short codes often fail on real phones with the same network message.  
AT dashboard → **Launch Simulator** → dial `*384*63693#` (or the channel AT shows).

### 5. Check AT Session Logs

AT dashboard → USSD → **Sessions** / logs for the failed call.  
You will see what AT got from your callback (502, timeout, wrong body, etc.).

## Quick self-test (PowerShell)

After health is OK:

```powershell
Invoke-WebRequest `
  -Uri "https://ecowatch-wu20.onrender.com/v1/ussd/webhook" `
  -Method POST `
  -ContentType "application/x-www-form-urlencoded" `
  -Body "sessionId=test&phoneNumber=%2B233200000000&serviceCode=*384*63693%23&text="
```

You must see a body starting with `CON Welcome to EcoWatch`.

## Panel explanation

> That message means the USSD gateway did not receive a valid callback response in time. On free hosting the server sleeps; we wake it first and demo USSD in the Africa's Talking simulator.
