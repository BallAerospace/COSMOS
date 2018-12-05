import { TestBed, inject } from '@angular/core/testing';

import { ConfigParserService } from './config-parser.service';

describe('ConfigParserService', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [ConfigParserService]
    });
  });

  it('should be created', inject([ConfigParserService], (service: ConfigParserService) => {
    expect(service).toBeTruthy();
  }));
});
