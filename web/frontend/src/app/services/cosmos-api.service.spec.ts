import { TestBed, inject } from '@angular/core/testing';

import { CosmosApiService } from './cosmos-api.service';

describe('CosmosApiService', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CosmosApiService]
    });
  });

  it('should be created', inject([CosmosApiService], (service: CosmosApiService) => {
    expect(service).toBeTruthy();
  }));
});
