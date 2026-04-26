document.addEventListener('DOMContentLoaded', () => {
    const menuItems = document.querySelectorAll('.nav-item');
    const tabs = document.querySelectorAll('.tab-content');

    menuItems.forEach(item => {
        item.addEventListener('click', function(e) {
            e.preventDefault();

            if (this.classList.contains('logout')) {
                alert("Saindo da conta...");
                return;
            }

            // Pega o nome da aba pelo atributo data-tab
            const targetTab = this.getAttribute('data-tab');

            // Remove active de todos os menus e esconde todas as abas
            menuItems.forEach(i => i.classList.remove('active'));
            tabs.forEach(tab => tab.style.display = 'none');

            // Ativa o menu clicado e mostra a aba correspondente
            this.classList.add('active');
            document.getElementById(targetTab).style.display = 'block';
        });
    });
});