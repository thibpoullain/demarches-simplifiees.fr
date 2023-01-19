id_rsa.pub -> clé publique utilisée par le serveur sftp de test (docker-compose)

id_rsa.pem -> clé privée dont le contenu peut être utilisée dans les variables d'env docker de la forme DEMAT_CUSTOM_EXPORT_SFTP_<client>_KEY_DATA
id_rsa.ppk -> clé au format putty (public + privée), qui peut être utilisée pour une connexion via  filezilla
MDP de ces clés privées : quelconque