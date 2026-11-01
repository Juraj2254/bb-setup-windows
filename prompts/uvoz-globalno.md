Ovo je jednokratni uvoz starog globalnog konteksta u zajedničku bb memoriju (Memory plugin).

Sažetak starog globalnog konteksta: {{FILE}}
Popis uvezenih projekata: {{INDEX}}

1. Pročitaj {{FILE}}. U njemu su globalne upute (CLAUDE.md, AGENTS.md), globalne memorije Claude Codea, Codexa i CROZ Codea te zadnji upiti iz sesija izvan projekata.
2. Izdvoji od 3 do 10 trajnih činjenica koje vrijede za sve projekte:
   - tko je korisnik, njegova uloga i način rada;
   - kako želi da mu agenti odgovaraju (jezik, ton, razina detalja);
   - alati, servisi i navike koje koristi u više projekata;
   - stalna pravila iz starih globalnih uputa koja i dalje vrijede.
3. Prije svakog upisa provjeri postoji li slična memorija:
   bb memory search "<tema>" --scope all --json
4. Svaku činjenicu upiši kao globalnu memoriju, na hrvatskom:
   bb memory add --scope global --name <kratko-ime-s-crticama> --summary "<jedna rečenica>" --details "<detalji>" --kind <preference|fact|procedure|reference> --tag uvoz --reason "Uvezeno iz starih globalnih uputa i sesija" --json
5. Dodaj i jednu globalnu memoriju s imenom stari-projekti: kratki popis projekata iz {{INDEX}} (ime, mapa, čemu služi ako se vidi).
6. Ne upisuj tajne (ključeve, lozinke, tokene), privremene statuse ni nagađanja. Ne mijenjaj nijednu datoteku.
7. Na kraju u dvije-tri rečenice na hrvatskom napiši što si upisao.
