document.addEventListener('DOMContentLoaded', () => {
    const configurator = document.querySelector('.configurator');
    const totalPriceElement = document.getElementById('total-price');

    // Preços correspondentes à ordem dos inputs no HTML
    const data = {
        vidro: [1200, 2800, 5500],
        filtro: [850, 1500],
        adicionais: [450, 600, 950]
    };

    function calculate() {
        let total = 0;

        // Soma Vidros
        document.querySelectorAll('input[name="vidro"]').forEach((el, i) => {
            if(el.checked) total += data.vidro[i];
        });

        // Soma Filtros
        document.querySelectorAll('input[name="filtro"]').forEach((el, i) => {
            if(el.checked) total += data.filtro[i];
        });

        // Soma Adicionais (Checkboxes)
        const checks = document.querySelectorAll('.config-card:last-child input[type="checkbox"]');
        checks.forEach((el, i) => {
            if(el.checked) total += data.adicionais[i];
        });

        // Atualiza o texto na tela
        totalPriceElement.innerText = total.toLocaleString('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        });
    }

    configurator.addEventListener('change', calculate);
    calculate(); // Inicia com o valor padrão
});

document.addEventListener('DOMContentLoaded', () => {
    const configurator = document.querySelector('.configurator');
    const totalPriceElement = document.getElementById('total-price-sal');

    // Dados de Preços Marinhos
    const dataSal = {
        vidro: [2500, 5800, 12000],
        filtro: [2200, 4500],
        adicionais: [900, 750, 2400]
    };

    function calculate() {
        let total = 0;

        // Soma Vidros
        document.querySelectorAll('input[name="vidro-sal"]').forEach((el, i) => {
            if(el.checked) total += dataSal.vidro[i];
        });

        // Soma Filtros/Skimmers
        document.querySelectorAll('input[name="filtro-sal"]').forEach((el, i) => {
            if(el.checked) total += dataSal.filtro[i];
        });

        // Soma Adicionais
        const checks = document.querySelectorAll('.config-card:last-child input[type="checkbox"]');
        checks.forEach((el, i) => {
            if(el.checked) total += dataSal.adicionais[i];
        });

        // Formata para R$
        totalPriceElement.innerText = total.toLocaleString('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        });
    }

    configurator.addEventListener('change', calculate);
    calculate(); // Inicializa o valor
});