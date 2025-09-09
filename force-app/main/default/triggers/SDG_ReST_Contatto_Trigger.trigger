trigger SDG_ReST_Contatto_Trigger on Contact (after insert, after update) {
    System.debug('Contatto creato o aggiornato');
    new SDG_ReST_Contatto_Handler().run();
}