Ovo je jednokratni uvoz starog konteksta u zajedničku bb memoriju (Memory plugin).

Projekt: {{NAME}}
Mapa projekta: {{PATH}}
Sažetak starog konteksta: {{FILE}}

1. Pročitaj datoteku {{FILE}}. U njoj su upute iz repozitorija (CLAUDE.md, AGENTS.md, README), stare memorije Claude Codea, Codexa i CROZ Codea te zadnji upiti iz starih sesija za ovaj projekt.
2. Ako nešto treba provjeriti, kratko pogledaj mapu projekta. Ne mijenjaj nijednu datoteku.
3. Izdvoji od 3 do 12 trajnih činjenica koje će pomoći budućem radu na ovom projektu:
   - čemu projekt služi i tko ga koristi;
   - kako se pokreće, gradi i testira (točne naredbe);
   - važne odluke, konvencije i struktura;
   - poznati problemi i zaobilaznice;
   - korisnikove želje za ovaj projekt.
4. Prije svakog upisa provjeri postoji li slična memorija:
   bb memory search "<tema>" --scope all --json
5. Svaku činjenicu upiši kao projektnu memoriju, na hrvatskom:
   bb memory add --scope project --name <kratko-ime-s-crticama> --summary "<jedna rečenica>" --details "<detalji, naredbe, putanje>" --kind <fact|decision|procedure|preference|reference> --tag uvoz --reason "Uvezeno iz starih sesija prije bb-a" --json
6. Ne upisuj tajne (ključeve, lozinke, tokene), privremene statuse, nagađanja ni ono što već doslovno piše u AGENTS.md ili CLAUDE.md u repozitoriju.
7. Na kraju u dvije-tri rečenice na hrvatskom napiši što si upisao.
